#include <iostream>
#include <array>
#include <thread>
#include <chrono>
#include <errno.h>
#include <sys/resource.h>
#include <signal.h>
#include <unistd.h>
#include <cstring>
#include <optional>

#define warn printf
#define fatal printf
#define USEC_PER_SEC 1000000
#define NSEC_PER_SEC 1000000000
// #define gettid() syscall(__NR_gettid)

static bool shutdown = false;
static int duration = 0;
static int aligned = 0;
static int secaligned = 0;
static int offset = 0;
static bool warming_up_over = false;
static pthread_barrier_t globalt_barr;
static pthread_barrier_t align_barr;
static timespec globalt;

void* func(void* arg) {
    // clock_nanosleep(0, 0, nullptr, nullptr);
    clock_gettime(0, nullptr);
    auto start = std::chrono::high_resolution_clock::now();
    std::this_thread::sleep_for(std::chrono::milliseconds(4000));
    auto end = std::chrono::high_resolution_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start);
    pthread_t tid = pthread_self();
    std::cout << "HELLO from: " << tid << ", took " << elapsed.count() <<  " ms\n";
	// std::cout << "Thread echo " << *static_cast<pthread_t*>(arg) << std::endl;
    return nullptr;
}

struct thread_statistics {
    unsigned long cycles;
    unsigned long cyclesread;
    long min;
    long max;
    long act;
    double avg;
    long *values;
    long *smis;
    long *hist_array;
    long *outliers;
    pthread_t thread;
    int threadstarted;
    int tid;
    long reduce;
    long redmax;
    long cycleofmax;
    long hist_overflow;
    long num_outliers;
    unsigned long smi_count;
};

struct thread_parameters {
    int prio;
    int policy;
    int mode;
    int timermode;
    int signal;
    int clock;
    unsigned long max_cycles;
    thread_statistics *stats;
    int bufmsk;
    unsigned long interval;
    int cpu;
    int node;
    int tnum;
    int msr_fd;
};

// void err_doit(int err, const char *fmt, va_list ap){
//     vfprintf(stderr, fmt, ap);
//     if (err)
//         fprintf(stderr, ": %s\n", strerror(err));
//     return;
// }

// void err_msg(char *fmt, ...){
//     va_list ap;
//     va_start(ap, fmt);
//     err_doit(0, fmt, ap);
//     va_end(ap);
//     return;
// }

// void err_msg_n(int err, char *fmt, ...) {
//     va_list ap;
//     va_start(ap, fmt);
//     err_doit(err, fmt, ap);
//     va_end(ap);
//     return;
// }

static inline int tsgreater(timespec *a, timespec *b) {
    return ((a->tv_sec > b->tv_sec) ||
        (a->tv_sec == b->tv_sec && a->tv_nsec > b->tv_nsec));
}

static inline void timespec_normalize(timespec &ts) {
    while (ts.tv_nsec >= NSEC_PER_SEC) {
        ts.tv_nsec -= NSEC_PER_SEC;
        ts.tv_sec++;
    }
}

static inline int64_t calcdiff(struct timespec t1, struct timespec t2) {
    int64_t diff;
    diff = USEC_PER_SEC * (long long)((int) t1.tv_sec - (int) t2.tv_sec);
    diff += ((int) t1.tv_nsec - (int) t2.tv_nsec) / 1000;
    return diff;
}

static int raise_soft_prio(int policy, const struct sched_param *param)
{
    int err;
    int policy_max; /* max for scheduling policy such as SCHED_FIFO */
    int soft_max;
    int hard_max;
    int prio;
    rlimit rlim;

    prio = param->sched_priority;

    policy_max = sched_get_priority_max(policy);
    if (policy_max == -1) {
        err = errno;
        // err_msg("WARN: no such policy\n");
        return err;
    }

    err = getrlimit(RLIMIT_RTPRIO, &rlim);
    if (err) {
        err = errno;
        // err_msg_n(err, "WARN: getrlimit failed");
        return err;
    }

    soft_max = (rlim.rlim_cur == RLIM_INFINITY) ? policy_max : rlim.rlim_cur;
    hard_max = (rlim.rlim_max == RLIM_INFINITY) ? policy_max : rlim.rlim_max;

    if (prio > soft_max && prio <= hard_max) {
        rlim.rlim_cur = prio;
        err = setrlimit(RLIMIT_RTPRIO, &rlim);
        if (err) {
            err = errno;
            // err_msg_n(err, "WARN: setrlimit failed");
            /* return err; */
        }
    } else {
        err = -1;
    }

    return err;
}

static int setscheduler(pid_t pid, int policy, const struct sched_param *param)
{
    int err = 0;

try_again:
    err = sched_setscheduler(pid, policy, param);
    if (err) {
        err = errno;
        if (err == EPERM) {
            int err1;
            err1 = raise_soft_prio(policy, param);
            if (!err1) goto try_again;
        }
    }

    return err;
}

void print_statistics(thread_parameters *parameters, const int index) {
    thread_statistics *statistics = parameters->stats;

    printf("T:%2d (%5d) P:%2d I:%ld C:%7lu Min:%7ld Act:%5ld Avg:%5ld Max:%8ld\n",
        index,
        statistics->tid,
        parameters->prio,
        parameters->interval,
        statistics->cycles,
        statistics->min,
        statistics->act,
        statistics->cycles ? (long)(statistics->avg/statistics->cycles) : 0,
        statistics->max);
}


void* timer_thread(void *thread_parameters_void) {
    thread_parameters* const parameters = reinterpret_cast<thread_parameters*>(thread_parameters_void);
    thread_statistics* const statistics = parameters->stats;
    timespec now, next, interval, stop;
    sigset_t sigset;
    bool warmed_up = false;

    cpu_set_t mask;
    CPU_ZERO(&mask);
    CPU_SET(parameters->cpu, &mask);
    pthread_t thread = pthread_self();

    // does not work
    if (pthread_setaffinity_np(thread, sizeof(mask), &mask) == -1) {
        warn("Could not set CPU affinity to CPU #%d\n", parameters->cpu);
    }

    interval.tv_sec = parameters->interval / USEC_PER_SEC;
    interval.tv_nsec = (parameters->interval % USEC_PER_SEC) * 1000;

    // does not work
    statistics->tid = gettid();

    sigemptyset(&sigset);
    sigaddset(&sigset, parameters->signal);
    sigprocmask(SIG_BLOCK, &sigset, NULL);

    struct sched_param scheduling_parameters;
    memset(&scheduling_parameters, 0, sizeof(scheduling_parameters));
    scheduling_parameters.sched_priority = parameters->prio;

    // does not work
    if (setscheduler(0, parameters->policy, &scheduling_parameters)) {
        fatal("timerthread%d: failed to set priority to %d\n", parameters->cpu, parameters->prio);
    }

    if (aligned || secaligned) {
        pthread_barrier_wait(&globalt_barr);
        if (parameters->tnum == 0) {
            clock_gettime(parameters->clock, &globalt);
            if (secaligned) {
                /* Ensure that the thread start timestamp is not
                   in the past */
                if (globalt.tv_nsec > 900000000)
                    globalt.tv_sec += 2;
                else
                    globalt.tv_sec++;
                globalt.tv_nsec = 0;
            }
        }
        pthread_barrier_wait(&align_barr);
        now = globalt;
        if (offset) {
            if (aligned)
                now.tv_nsec += offset * parameters->tnum;
            else
                now.tv_nsec += offset;
            timespec_normalize(now);
        }
    } else {
        clock_gettime(parameters->clock, &now);
    }

    next = now;
    next.tv_sec += interval.tv_sec;
    next.tv_nsec += interval.tv_nsec;
    timespec_normalize(next);

    if (duration) {
        memset(&stop, 0, sizeof(stop)); /* grrr */
        stop = now;
        stop.tv_sec += duration;
    }

    statistics->threadstarted++;

    while(!shutdown) {
        const int clock_nanosleep_rv = clock_nanosleep(parameters->clock, TIMER_ABSTIME, &next, NULL);
        if (clock_nanosleep_rv != 0) {
            if (clock_nanosleep_rv != EINTR){
                warn("clock_nanosleep failed. errno: %d\n", errno);
            }
            break;
        }

        const int clock_gettime_rv = clock_gettime(parameters->clock, &now);
        if (clock_gettime_rv != 0) {
            if (clock_gettime_rv != EINTR) {
                warn("clock_getttime() failed. errno: %d\n", errno);
            }
            break;
        }

        const uint64_t difference = calcdiff(now, next);
        if (difference < statistics->min) {
            statistics->min = difference;
        }
        if (difference > statistics->max) {
            statistics->max = difference;
        }
        statistics->avg += (double)difference;
        statistics->act = difference;

        statistics->cycles++;

        next.tv_sec += interval.tv_sec;
        next.tv_nsec += interval.tv_nsec;
        timespec_normalize(next);

        while (tsgreater(&now, &next)) {
            next.tv_sec += interval.tv_sec;
            next.tv_nsec += interval.tv_nsec;
            timespec_normalize(next);
        }

        if (!warmed_up && warming_up_over) {
            statistics->min = 1000000;
            statistics->max = 0;
            statistics->avg = 0.0;
            statistics->threadstarted = 1;
            statistics->smi_count = 0;
            warmed_up = true;
        }
    }

    return nullptr;
}

void create_timer_thread(thread_parameters **parameters_array, thread_statistics **statistics_array, const int thread_number) {
    const int max_cpus = sysconf(_SC_NPROCESSORS_ONLN);

    thread_parameters * const parameters = new thread_parameters;
    memset(parameters, 0, sizeof(thread_parameters));
    parameters_array[thread_number] = parameters;

    thread_statistics * const statistics = new thread_statistics;
    memset(statistics, 0, sizeof(thread_statistics));
    statistics_array[thread_number] = statistics;

    pthread_attr_t attr;
    const int pthread_attr_init_call_rv = pthread_attr_init(&attr);
    if (pthread_attr_init_call_rv != 0) {
        fatal("error from pthread_attr_init for thread %d: %s\n", thread_number, strerror(pthread_attr_init_call_rv));
    }

    parameters->prio = 80;
    parameters->policy = 1;
    parameters->clock = 1;
    parameters->mode = 1;
    parameters->timermode = 1;
    parameters->signal = 14;
    parameters->interval = 200;
    parameters->max_cycles = 0;
    parameters->stats = statistics;
    parameters->node = -1;
    parameters->tnum = thread_number;
    parameters->cpu = thread_number % max_cpus;
    statistics->min = 1000000;
    statistics->max = 0;
    statistics->avg = 0.0;
    statistics->threadstarted = 1;
    statistics->smi_count = 0;

    const int pthread_create_call_rv = pthread_create(&statistics->thread, &attr, timer_thread, parameters);
    if (pthread_create_call_rv) {
        fatal("failed to create thread %d: %s\n", thread_number, strerror(pthread_create_call_rv));
    }
}


void main_loop(const int thread_count, const int running_time_us) {
    thread_parameters ** const parameters_array = new thread_parameters*[thread_count];
    thread_statistics ** const statistics_array = new thread_statistics*[thread_count];

    for(int i = 0; i < thread_count; i++) {
        std::cout << "creating thread" << std::endl;
        create_timer_thread(parameters_array, statistics_array, i);
        std::cout << "thread created" << std::endl;
    }

    usleep(2'000'000);
    std::cout << "warmup finished" << std::endl;
    warming_up_over = true;
    usleep(running_time_us);
    shutdown = true;
    usleep(100'000);
    for(int i = 0; i < thread_count; i++) {
        print_statistics(parameters_array[i], i);
    }
}

int parse_nth_arg_as_int(int argc, char const *argv[], int position, int default_value) {
    if (argc <= position) {
        return default_value;
    }

    int value = std::atoi(argv[position]);

    if (value) {
        return value;
    }
    
    return default_value;
}

int main(int argc, char const *argv[]){
    const int threads_to_use = parse_nth_arg_as_int(argc, argv, 1, 4);
    const int run_for_us = parse_nth_arg_as_int(argc, argv, 2, 30'000'000);
    main_loop(threads_to_use, run_for_us);
    std::cout << "Main loop finished" << std::endl;



	// constexpr int thread_count = 5;
	// std::array<pthread_t, thread_count> thread_ids;

 //    std::cout << "Starting thread creation" << std::endl;

	// for(int i = 0; i < thread_count; i++) {
	// 	pthread_create(&thread_ids[i], NULL, &func, (&thread_ids[0])+i);
 //        std::cout << "Created thread: " << i << ", " << thread_ids[i] << ", or the same: " << *((&thread_ids[0])+i) << std::endl;
 //        // std::this_thread::sleep_for(std::chrono::milliseconds(1500));
	// }

 //    std::cout << "Created all threads" << std::endl;
    
 //    for(int i = 0; i < thread_count; i++) {
 //    	pthread_join(thread_ids[i], NULL); 
 //    }

 //    std::cout << "All thread exited" << std::endl;
 //    std::this_thread::sleep_for(std::chrono::milliseconds(4000));
 //    std::cout << "Done" << std::endl;

	// // int pthread_create(pthread_t * thread, const pthread_attr_t * attr, void * (*start_routine)(void *), void *arg);
	return 0;
}