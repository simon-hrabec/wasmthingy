#include <chrono>
#include <iostream>
#include <vector>
#include <limits>
#include <thread>

#include <unistd.h>
#include <pthread.h>
#include <string.h>

#include <chrono>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <vector>

std::chrono::microseconds interval{3000};
static bool shutdown = false;
static bool warming_up_over = false;
constexpr int latency_array_size = 3000;
constexpr int jitter_array_size = 4000;
constexpr int jitter_offset = 4000/2;


int64_t parse_nth_arg_as_int(int argc, char const *argv[], int position, int64_t default_value) {
    if (argc <= position) {
        return default_value;
    }

    int value = std::atoll(argv[position]);

    if (value) {
        return value;
    }
    
    return default_value;
}

struct thread_instance_statistics {
	std::array<int64_t, latency_array_size> latency_data;
	std::vector<int64_t> additional_latencies;
	std::array<int64_t, jitter_array_size> jitter_data;
	std::vector<int64_t> additional_jitter;
	int64_t minimum;
	int64_t maximum;
	int64_t total;
	int64_t cycles;

	void reset() {
		latency_data.fill(0);
		jitter_data.fill(0);
		additional_latencies.resize(0);
		additional_jitter.resize(0);
    	minimum = std::numeric_limits<decltype(minimum)>::max();
    	maximum = 0;
    	total = 0;
    	cycles = 0;
	}
};

struct thread_instance_data {
	pthread_t thread;
	int thread_id;
	
	thread_instance_statistics statistics;
};

#ifndef POSIX_SLEEP
std::pair<int64_t, int64_t> wake_up_latency(std::chrono::time_point<std::chrono::high_resolution_clock> &previous_wakeup_time, std::chrono::time_point<std::chrono::high_resolution_clock> &next_wakeup_time) {
	std::this_thread::sleep_until(next_wakeup_time);
	const auto now_time = std::chrono::high_resolution_clock::now();
	const int64_t latency = std::chrono::duration_cast<std::chrono::microseconds>(now_time - next_wakeup_time).count();
    const int64_t jitter = std::chrono::duration_cast<std::chrono::microseconds>(now_time - previous_wakeup_time - interval).count();

    previous_wakeup_time = now_time;
	while(next_wakeup_time < now_time) {
		next_wakeup_time += interval;
	}
	return {latency, jitter};
}
#else
void add_interval(timespec &timestamp, std::chrono::microseconds interval_to_add) {
	timestamp.tv_nsec += interval_to_add.count() * 1000;
	while(timestamp.tv_nsec >= 1000000000) {
		timestamp.tv_nsec -= 1000000000;
		timestamp.tv_sec++;
	}
}

std::pair<int64_t, int64_t> wake_up_latency(timespec &previous_wakeup_time, timespec &next_wakeup_time) {
	clock_nanosleep(1, TIMER_ABSTIME, &next_wakeup_time, NULL);
	timespec now_time;
	clock_gettime(1, &now_time);

	const int64_t latency = (1000000 * (long long)((int) now_time.tv_sec - (int) next_wakeup_time.tv_sec)) + (((int) now_time.tv_nsec - (int) next_wakeup_time.tv_nsec) / 1000);
    const int64_t jitter = (1000000 * (long long)((int) now_time.tv_sec - (int) previous_wakeup_time.tv_sec)) + (((int) now_time.tv_nsec - (int) previous_wakeup_time.tv_nsec) / 1000);

    previous_wakeup_time = now_time;

    while(std::tie(now_time.tv_sec, now_time.tv_nsec) >  std::tie(next_wakeup_time.tv_sec, next_wakeup_time.tv_nsec)) {
    	add_interval(next_wakeup_time, interval);
    }

    return {latency, jitter-interval};
}
#endif

void print_statistics(const thread_instance_data& data) {
	std::cout << "ID: " << data.thread_id << ", MIN: " << data.statistics.minimum << ", MAX: " << data.statistics.maximum << ", AVERAGE: " << double(data.statistics.total)/data.statistics.cycles << std::endl;
}

void* timer_thread(void* parameters) {
	thread_instance_data& thread_data = *reinterpret_cast<thread_instance_data*>(parameters);
	std::cout << "Timer thread " << thread_data.thread_id << " started" << std::endl;
	thread_data.statistics.additional_latencies.reserve(2000);
	thread_data.statistics.reset();

	bool warmed_up = false;
	// int64_t previous_latency = 0;

#ifdef POSIX_PRORITY_SETUP
	const int max_cpus = sysconf(_SC_NPROCESSORS_ONLN);
	cpu_set_t mask;
    CPU_ZERO(&mask);
    CPU_SET(thread_data.thread_id % max_cpus, &mask);
    pthread_setaffinity_np(pthread_self(), sizeof(mask), &mask);
    sched_param scheduling_parameters;
    sched_setscheduler(0, SCHED_FIFO, &scheduling_parameters);
#endif

#ifndef POSIX_SLEEP
    std::chrono::time_point<std::chrono::high_resolution_clock> next_wakeup_time = std::chrono::high_resolution_clock::now() + interval;
    std::chrono::time_point<std::chrono::high_resolution_clock> previous_wakeup_time = next_wakeup_time;
#else
    timespec next_wakeup_time;
    timespec previous_wakeup_time;
    clock_gettime(1, &next_wakeup_time);
    previous_wakeup_time = next_wakeup_time;
    add_interval(next_wakeup_time, interval);
#endif

	while(!shutdown) {
		if (!warmed_up && warming_up_over) {
			thread_data.statistics.reset();
			warmed_up = true;
#ifndef POSIX_SLEEP
    		next_wakeup_time = std::chrono::high_resolution_clock::now() + interval;
#else
    		add_interval(next_wakeup_time, interval);
#endif
		}

		const auto [latency, jitter] = wake_up_latency(previous_wakeup_time, next_wakeup_time);

		if (latency < latency_array_size) {
			thread_data.statistics.latency_data[latency]++;
		} else {
			thread_data.statistics.additional_latencies.push_back(latency);
		}

        const auto jitter_encoded = jitter + jitter_offset;
		if (jitter_encoded >= 0 && jitter_encoded < jitter_array_size) {
			thread_data.statistics.jitter_data[jitter_encoded]++;
		} else {
			thread_data.statistics.additional_jitter.push_back(jitter);
		}

		if (latency < thread_data.statistics.minimum) {
			thread_data.statistics.minimum = latency;
		}

		if (latency > thread_data.statistics.maximum) {
			thread_data.statistics.maximum = latency;
		}

		thread_data.statistics.total += latency;
		thread_data.statistics.cycles++;
	}
	std::cout << "Timer thread " << thread_data.thread_id << " shutting down" << std::endl;
	return nullptr;
}

thread_instance_data create_timer_thread(std::vector<thread_instance_data> &thread_data_array, const int thread_id){
	thread_instance_data& thread_data = thread_data_array[thread_id];
	thread_data.thread_id = thread_id;

	pthread_attr_t attr;
    const int pthread_attr_init_call_rv = pthread_attr_init(&attr);
    if (pthread_attr_init_call_rv != 0) {
        std::cout << "error from pthread_attr_init for thread " << thread_id << ", " << strerror(pthread_attr_init_call_rv) << std::endl;
		exit(1);
    }

	const int pthread_create_call_rv = pthread_create(&thread_data.thread, &attr, timer_thread, &thread_data);
    if (pthread_create_call_rv) {
        std::cout << "failed to create thread " << thread_id << ", " << strerror(pthread_create_call_rv) << std::endl;
        exit(1);
    }
	return thread_data;
}

void main_loop(const int thread_count, std::chrono::microseconds run_for) {
	std::vector<thread_instance_data> thread_data(thread_count);

    for(int i = 0; i < thread_count; i++) {
        std::cout << "creating thread" << std::endl;
        thread_data[i] = create_timer_thread(thread_data, i);
        std::cout << "thread created" << std::endl;
    }

    std::this_thread::sleep_for(std::chrono::seconds(2));
    std::cout << "warmup finished" << std::endl;
    warming_up_over = true;
    std::this_thread::sleep_for(run_for);
    shutdown = true;
    std::this_thread::sleep_for(std::chrono::seconds(2));

    for(int i = 0; i < thread_count; i++) {
    	std::cout << "joining thread " << i << std::endl;
    	pthread_join(thread_data[i].thread, nullptr);
    	std::cout << "thread " << i << " joined" << std::endl;
    }

    for(int i = 0; i < thread_count; i++) {
    	std::cout << "printing statis for " << i << std::endl;
    	print_statistics(thread_data[i]);
    }

    for(int i = 0; i < thread_count; i++) {
    	std::cout << i << ", LATENCY_DATA: ";
    	for(int j = 0; j < latency_array_size; j++) {
    		for(int k = 0; k < thread_data[i].statistics.latency_data[j]; k++) {
    			std::cout << ";" << j << std::flush;
    		}
    	}
    	for(const auto num : thread_data[i].statistics.additional_latencies) {
    		std::cout << ";" << num << std::flush;
    	}
    }
    std::cout << std::endl;

    for(int i = 0; i < thread_count; i++) {
    	std::cout << i << ", JITTER_DATA: ";
    	for(int j = 0; j < jitter_array_size; j++) {
    		for(int k = 0; k < thread_data[i].statistics.jitter_data[j]; k++) {
    			std::cout << ";" << (j-jitter_offset) << std::flush;
    		}
    	}
    	for(const auto num : thread_data[i].statistics.additional_jitter) {
    		std::cout << ";" << num << std::flush;
    	}
    }
    std::cout << std::endl;
}

int main(int argc, char const *argv[]){
    const int threads_to_use = parse_nth_arg_as_int(argc, argv, 1, 4);
    const std::chrono::microseconds run_for_us = std::chrono::microseconds{parse_nth_arg_as_int(argc, argv, 2, 30'000'000)};

    std::cout << "Creating " << threads_to_use << " threads" << std::endl;
    main_loop(threads_to_use, run_for_us);
    std::cout << "Main loop finished" << std::endl;
	return 0;
}