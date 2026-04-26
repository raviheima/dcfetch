#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdbool.h>

#include <dict.h>
#include <dict_util.h>

#if defined(__linux__)
    #include <dirent.h>

    #define CPU_IDLE_STATE 3
    #define CPU_STATES_NUM 10
#elif defined(__APPLE__)
    #include <mach/mach.h>

    #define CPU_IDLE_STATE 2
    #define CPU_STATES_NUM 4
#endif

static long long cpu_usage[CPU_STATES_NUM];
static long long cpu_usage_prev[CPU_STATES_NUM] = { 0 };

static int get_cpu_usage_percent(long long *cpu_usage, long long *cpu_usage_prev) {	
    long long cpu_usage_sum = 0;
    long long cpu_non_idle_usage_sum = 0;
    
    for (int i = 0; i < CPU_STATES_NUM; i++) {
        cpu_usage_sum += cpu_usage[i] - cpu_usage_prev[i];
    }

    long long cpu_idle = cpu_usage[CPU_IDLE_STATE] - cpu_usage_prev[CPU_IDLE_STATE];
    cpu_non_idle_usage_sum = cpu_usage_sum - cpu_idle;

    for (int i = 0; i < CPU_STATES_NUM; i++) {
        cpu_usage_prev[i] = cpu_usage[i];
    }

    return 100.0f * cpu_non_idle_usage_sum / cpu_usage_sum;
}

#if defined(__linux__)
	int get_cpu_usage(void) {
        	FILE *fp;
        	char line[512];

        	fp = fopen("/proc/stat", "r");

        	if (fp == NULL) {
            		return 0;
        	}

        	fgets(line, sizeof(line), fp);
        	fclose(fp);

        	sscanf(
            		line,
            		"cpu %lld %lld %lld %lld %lld %lld %lld %lld %lld %lld",
            		&cpu_usage[0], &cpu_usage[1], &cpu_usage[2], &cpu_usage[3], &cpu_usage[4], &cpu_usage[5], &cpu_usage[6], &cpu_usage[7], &cpu_usage[8], &cpu_usage[9]
        	);

        	return get_cpu_usage_percent(cpu_usage, cpu_usage_prev);
 	}
#elif defined(__APPLE__)
	int get_cpu_usage(void) {
        	natural_t proc_count;
        	mach_msg_type_number_t len = HOST_VM_INFO64_COUNT;
        	processor_cpu_load_info_t cpu_load_info;

        	int ret = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &proc_count, (processor_info_array_t *)&cpu_load_info, &len);

        	if (ret == -1) {
            		return 0;
        	}

        	for (int i = 0; i < CPU_STATES_NUM; i++) {
            		cpu_usage[i] = 0;
            		for (unsigned int j = 0; j < proc_count; j++) {
                		cpu_usage[i] += cpu_load_info[j].cpu_ticks[i];
            		}
        	}

        	return get_cpu_usage_percent(cpu_usage, cpu_usage_prev);
    	}
#endif
