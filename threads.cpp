#include <iostream>
#include <array>
#include <thread>
#include <chrono>

void func() {
	std::cout << "Thread echo " << std::this_thread::get_id() << std::endl;
} 

int main(int argc, char const *argv[]){
	constexpr int thread_count = 10;
	std::array<std::thread, thread_count> threads;

    std::cout << "Starting thread creation" << std::endl;

	for(int i = 0; i < thread_count; i++) {
		std::this_thread::sleep_for(std::chrono::milliseconds(1500));
		// threads[i] = std::thread(func);
        std::cout << "Created thread: " << i << ", " << threads[i].get_id() << std::endl;
	}

    std::cout << "Created all threads" << std::endl;
    
    // for(std::thread& thread : threads) {
    // 	thread.join();
    // }

    std::cout << "All thread exited" << std::endl;

	// int pthread_create(pthread_t * thread, const pthread_attr_t * attr, void * (*start_routine)(void *), void *arg);
	return 0;
}