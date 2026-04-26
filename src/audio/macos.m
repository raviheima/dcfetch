#include <stdbool.h>

#include <rpc.h>
#include <data.h>
#include <dict.h>
#include <dict_util.h>

#import <Foundation/Foundation.h>

extern void MRMediaRemoteGetNowPlayingInfo(dispatch_queue_t dispatcher, void(^handler)(NSDictionary *info));
extern void MRMediaRemoteGetNowPlayingApplicationDisplayName(int unknown, dispatch_queue_t queue, void (^handler)(NSString *name));
extern void MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_queue_t queue, void (^handler)(Boolean playing));

extern struct dicts config;
extern struct dicts os_details;

char *filter_apps_vis = NULL;
bool isPlaying, validApp = false;

void get_currently_playing_media(const char *filter_apps) {
	dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

	if (strcmp(filter_apps, "") != 0)
		filter_apps_vis = strdup(filter_apps);

    dispatch_group_enter(group);
	MRMediaRemoteGetNowPlayingApplicationIsPlaying(queue, ^(Boolean playing) {
		if (playing) {
			isPlaying = true;
		}

		dispatch_group_leave(group);
	});

	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

	if (!isPlaying)
		return;

 	dispatch_group_enter(group);
	MRMediaRemoteGetNowPlayingApplicationDisplayName(0, queue, ^(NSString *name) {
		const char *app_name_C = [name UTF8String];

		if (filter_apps_vis != NULL) {
			if (strcasestr(filter_apps_vis, app_name_C) != NULL) {
				validApp = true;
			}
		} else {
			validApp = true;
		}

		dispatch_group_leave(group);
	});

	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

	if (!validApp)
		return;

	dispatch_group_enter(group);
	MRMediaRemoteGetNowPlayingInfo(queue, ^(NSDictionary *info) {
		if (info != NULL) {
			NSString *media_title = [info objectForKey:@"kMRMediaRemoteNowPlayingInfoTitle"];
			printf("%s", [media_title UTF8String]);
		}

		dispatch_group_leave(group);
	});

	if (filter_apps_vis != NULL)
		free(filter_apps_vis);

	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

bool init_audio(int argc, char *argv[]) {
	pid_t pid;
	int pipes[2];
	char py_code[1024], media_title[4096];

	char *filter_apps = get_dict_value("FILTER_MEDIA_APPLICATIONS", &config);

	// workaround since python has permissions for MediaRemote
	snprintf(py_code, sizeof(py_code), 
		"import ctypes;ctypes.CDLL('%s').get_currently_playing_media('%s'.encode('utf-8'))", argv[0], filter_apps != NULL ? filter_apps : ""
	);

	for (;;) {
		pipe(pipes);

		pid = fork();

		if (pid == 0) {
			dup2(pipes[1], STDOUT_FILENO);
			close(pipes[0]);
			close(pipes[1]);
			char *execvp_args[] = { "/usr/bin/python3", "-c", py_code, NULL};
			execvp(execvp_args[0], execvp_args);
			exit(0);
		} else {
			close(pipes[1]);
			ssize_t read_len = read(pipes[0], media_title, sizeof(media_title));
			
			if (read_len > 0) {
				media_title[read_len] = '\0';
				set_activity("Listening to music", media_title, get_dict_value("OS_IMAGE", &os_details));
			} else {
				set_os_activity();
			}

			wait(NULL);
		}

		sleep(5);
	}

	return true;
}
