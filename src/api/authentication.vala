using Jellygtk.Api.Models;
using Gee;

namespace Jellyfin.Api {

    public class Authentication {

        public static string auth_token;
        public static string authorization;
        public static string authorization_with_token;
        public static User current_user;
        public static new Jellygtk.Application Application {get; set;}


        public static int login (LoginData login_data, string url) {
            authorization = "MediaBrowser Client=\"other\", Device=\"my-script\", DeviceId=\"some-unique-id\", Version=\"0.0.0\"";
            var session = new Soup.Session ();
            var soup_msg = new Soup.Message ("POST", url + "/Users/AuthenticateByName");
            string json_response;
            soup_msg.request_headers.append ("Authorization", authorization);
            message ("header: " + soup_msg.request_headers.get_one ("Authorization"));
            if (soup_msg == null) {
                message ("invalid url");
                return -1;
            }

            var gen = new Json.Generator ();

            Json.Node json_node = login_data.to_json ();

            gen.set_root(json_node);


            int response = get_login_response (out json_response ,session, soup_msg, gen);

            if (response != 0) {
                return -1;
            }

            string access_token = set_token (json_response);
            string store_token_result = store_token (access_token);
            string store_url_result = store_url (url);

            if (store_token_result != "success") {
                message ("Failure:" + store_token_result);
                return -1;
            }

            if (store_url_result != "success") {
                message ("Failure:" + store_url_result);
                return -1;
            }

            message (store_token_result);
            message (store_url_result);
            message (access_token);
            message (current_user.name);
            return 0;
        }


        public static int get_login_response(out string json_response, Soup.Session session, Soup.Message msg, Json.Generator gen) {

            size_t json_length;

            string json_string = gen.to_data (out json_length);
            if (json_length == 0) {
                return -1;
            }
            message (json_string);

            msg.set_request_body ("application/json", new GLib.MemoryInputStream.from_data
                (json_string.data, GLib.g_free), (ssize_t)json_length);

            try {
                Bytes bytes = session.send_and_read(msg, null);
                if (msg.status_code != 200) {
                    message ("Json response code: " + msg.status_code.to_string ());
                    return -1;
                }
                json_response = (string)bytes.get_data();
                return 0;
            } catch (Error e) {
                message (e.message);
                return -1;
            }
        }

        public static string set_token (string response) {

            Json.Parser parser = new Json.Parser ();

            try {
		        parser.load_from_data (response);

		        // Get the root node:
		        Json.Node root_node = parser.get_root();

		        Json.Object root_obj = root_node.get_object();

		        string access_token = root_obj.get_string_member("AccessToken");

		        authorization_with_token = authorization + @", Token=\"$access_token\"";
		        auth_token = access_token;
		        message("authorization with token: " + authorization_with_token);

                User user =  new User();
                Json.Object user_obj = root_obj.get_object_member ("User");
                int set_usr_success = set_user_info(out user, user_obj);

                if (set_usr_success != 0) {
                    return "failure getting";
                }
                current_user = user;
                return access_token;
	        } catch (Error e) {
		      message (response);
	        }
            return "Unable to load json";
        }

        public static string store_token (string input_token) {
            string data_path = Environment.get_user_data_dir ();
            string token_file_path = data_path + "/token.txt";

            File token_file = File.new_for_path(token_file_path);

            if (token_file.query_exists()) {

                try {
                    token_file.delete();
                } catch (Error e) {
                    return "unable delete existing token file ERROR: \n" + e.message;
                }
            }

            var dos = new DataOutputStream (token_file.create(FileCreateFlags.REPLACE_DESTINATION));

            try {
                dos.put_string(input_token);
            } catch (Error e) {
                return "unable put data in token file ERROR: \n" + e.message;
            }

            try {
                dos.close();
            } catch (Error e) {
                return "unable to close the file ERROR: \n" + e.message;
            }


            return "success";
        }

        public static string store_url (string url) {
            string data_path = Environment.get_user_data_dir ();
            string url_file_path = data_path + "/url.txt";

            File url_file = File.new_for_path(url_file_path);

            if (url_file.query_exists()) {

                try {
                    url_file.delete();
                } catch (Error e) {
                    return "unable delete existing token file ERROR: \n" + e.message;
                }
            }

            var dos = new DataOutputStream (url_file.create(FileCreateFlags.REPLACE_DESTINATION));

            try {
                dos.put_string(url);
            } catch (Error e) {
                return "unable put data in token file ERROR: \n" + e.message;
            }

            try {
                dos.close();
            } catch (Error e) {
                return "unable to close the file ERROR: \n" + e.message;
            }


            return "success";
        }

        public static bool authenticate_using_token () {
            string access_token;
            string url;
            string json_res;
            int read_token_response = read_token (out access_token);
            int read_url_response = read_url (out url);

            if (read_token_response == -1 || read_url_response == -1) {
                return false;
            }

            if (get_user_response(url, access_token, out json_res) == -1) {
                return false;
            }

            message (json_res);
            int get_user_res = get_user_info(json_res);

            message (current_user.name);

            return true;
        }

        public static int read_token (out string access_token) {
            string data_path = Environment.get_user_data_dir ();
            string token_file_path = data_path + "/token.txt";

            File token_file = File.new_for_path(token_file_path);

            if (!token_file.query_exists()) {
                return -1;
            }

            try {
                var dis = new DataInputStream(token_file.read ());
                access_token = dis.read_line (null);
            } catch (Error e) {

                return -1;
            }

            return 0;
        }


        public static int read_url (out string url) {
            string data_path = Environment.get_user_data_dir ();
            string token_file_path = data_path + "/url.txt";

            File token_file = File.new_for_path(token_file_path);

            if (!token_file.query_exists()) {
                return -1;
            }

            try {
                var dis = new DataInputStream(token_file.read ());
                url = dis.read_line (null);
            } catch (Error e) {

                return -1;
            }

            return 0;
        }

        public static int get_user_response (string url, string access_token, out string json_res) {
            json_res = "";
            string test_auth_access_token = @"MediaBrowser Client=\"other\", Device=\"my-script\", DeviceId=\"some-unique-id\", Version=\"0.0.0\", Token=\"$access_token\"";

            var session = new Soup.Session ();
            var soup_msg = new Soup.Message ("GET", url + "/Users/Me");
            soup_msg.request_headers.append ("Authorization", test_auth_access_token);
            message ("header: " + soup_msg.request_headers.get_one ("Authorization"));
            if (soup_msg == null) {
                return -1;
            }

            try {
                Bytes bytes = session.send_and_read(soup_msg, null);
                if (soup_msg.status_code != 200) {
                    return -1;
                }
                message(soup_msg.status_code.to_string ());
                json_res = (string)bytes.get_data();
                auth_token = access_token;
                authorization_with_token = test_auth_access_token;
                return 0;
            } catch (Error e) {
                message (e.message);
                return -1;
            }
        }

        public static int delete_auth_files () {
            string data_path = Environment.get_user_data_dir ();
            string url_file_path = data_path + "/url.txt";
            string token_file_path = data_path + "/token.txt";

            File url_file = File.new_for_path(url_file_path);
            File token_file = File.new_for_path(token_file_path);

            if (url_file.query_exists()) {

                try {
                    url_file.delete();
                    token_file.delete();
                } catch (Error e) {
                    return -1;
                }
            }
            return 0;
        }

        public static int get_user_info (string json_res) {
            User user;
            Json.Parser parser = new Json.Parser ();

            try {
		        parser.load_from_data (json_res);
		        // Get the root node:
		        Json.Node root_node = parser.get_root();

		        Json.Object root_obj = root_node.get_object();

                int set_info_stat = set_user_info (out user, root_obj);

                if (set_info_stat != 0) {
                    return -1;
                }
                current_user = user;
	        } catch (Error e) {
		        message (e.message);
                return -1;
	        }

            return 0;
        }

        public static int set_user_info (out User user, Json.Object user_obj) {
            user = new User();

            user.name = user_obj.get_string_member ("Name");
            user.server_id = user_obj.get_string_member ("ServerId");
            user.id = user_obj.get_string_member ("Id");
            user.has_password = user_obj.get_boolean_member ("HasPassword");
            user.has_configured_password = user_obj.get_boolean_member ("HasConfiguredPassword");
            user.has_configured_easy_password = user_obj.get_boolean_member ("HasConfiguredEasyPassword");
            user.enable_auto_login = user_obj.get_boolean_member ("EnableAutoLogin");
            user.last_login_date = new DateTime.from_iso8601 (user_obj.get_string_member ("LastLoginDate"), new TimeZone.utc ());
            user.last_activity_date = new DateTime.from_iso8601 (user_obj.get_string_member ("LastActivityDate"), new TimeZone.utc ());

            Json.Object conf_obj = user_obj.get_object_member ("Configuration");

            user.configuration = new UserConfiguration();

            user.configuration.play_default_audio_track = conf_obj.get_boolean_member ("PlayDefaultAudioTrack");
            user.configuration.subtitle_language_preference = conf_obj.get_string_member ("SubtitleLanguagePreference");
            user.configuration.display_missing_episodes = conf_obj.get_boolean_member ("DisplayMissingEpisodes");

            user.configuration.grouped_folders = new ArrayList<string>();
            for (int i = 0; i < conf_obj.get_array_member ("GroupedFolders").get_length (); i++) {
                user.configuration.grouped_folders.add (conf_obj.get_array_member ("GroupedFolders").get_string_element (i));
            }

            user.configuration.subtitle_mode = conf_obj.get_string_member ("SubtitleMode");
            user.configuration.display_collections_view = conf_obj.get_boolean_member ("DisplayCollectionsView");
            user.configuration.enable_local_password = conf_obj.get_boolean_member ("EnableLocalPassword");

            user.configuration.ordered_views = new ArrayList<string>();
            for (int i = 0; i < conf_obj.get_array_member ("OrderedViews").get_length (); i++) {
                user.configuration.ordered_views.add (conf_obj.get_array_member ("OrderedViews").get_string_element (i));
            }

            user.configuration.latest_items_excludes = new ArrayList<string>();
            for (int i = 0; i < conf_obj.get_array_member ("LatestItemsExcludes").get_length (); i++) {
                user.configuration.latest_items_excludes.add (conf_obj.get_array_member ("LatestItemsExcludes").get_string_element (i));
            }

            user.configuration.my_media_excludes = new ArrayList<string>();
            for (int i = 0; i < conf_obj.get_array_member ("MyMediaExcludes").get_length (); i++) {
                user.configuration.my_media_excludes.add (conf_obj.get_array_member ("MyMediaExcludes").get_string_element (i));
            }

            user.configuration.hide_played_in_latest = conf_obj.get_boolean_member ("HidePlayedInLatest");
            user.configuration.remember_audio_selections = conf_obj.get_boolean_member ("RememberAudioSelections");
            user.configuration.remember_subtitle_selections = conf_obj.get_boolean_member ("RememberSubtitleSelections");
            user.configuration.enable_next_episode_auto_play = conf_obj.get_boolean_member ("EnableNextEpisodeAutoPlay");

            Json.Object policy_obj = user_obj.get_object_member ("Policy");

            user.policy = new UserPolicy ();

            user.policy.is_administrator = policy_obj.get_boolean_member ("IsAdministrator");
            user.policy.is_hidden = policy_obj.get_boolean_member ("IsHidden");
            user.policy.is_disabled = policy_obj.get_boolean_member ("IsDisabled");

            user.policy.blocked_tags = new ArrayList<string>();
            for (int i = 0; i < policy_obj.get_array_member ("BlockedTags").get_length (); i++) {
                user.policy.blocked_tags.add (policy_obj.get_array_member ("BlockedTags").get_string_element (i));
            }

            user.policy.enable_user_preference_access = policy_obj.get_boolean_member ("EnableUserPreferenceAccess");

            user.policy.access_schedules = new ArrayList<string>();
            for (int i = 0; i < policy_obj.get_array_member ("AccessSchedules").get_length (); i++) {
                user.policy.access_schedules.add (policy_obj.get_array_member ("AccessSchedules").get_string_element (i));
            }

            user.policy.block_unrated_items = new ArrayList<string>();
            for (int i = 0; i < policy_obj.get_array_member ("BlockUnratedItems").get_length (); i++) {
                user.policy.block_unrated_items.add (policy_obj.get_array_member ("BlockUnratedItems").get_string_element (i));
            }

            user.policy.enable_remote_control_of_other_users = policy_obj.get_boolean_member ("EnableRemoteControlOfOtherUsers");
            user.policy.enable_shared_device_control = policy_obj.get_boolean_member ("EnableSharedDeviceControl");
            user.policy.enable_remote_access = policy_obj.get_boolean_member ("EnableRemoteAccess");
            user.policy.enable_live_tv_management = policy_obj.get_boolean_member ("EnableLiveTvManagement");
            user.policy.enable_live_tv_access = policy_obj.get_boolean_member ("EnableLiveTvAccess");
            user.policy.enable_media_playback = policy_obj.get_boolean_member ("EnableMediaPlayback");
            user.policy.enable_audio_playback_transcoding = policy_obj.get_boolean_member ("EnableAudioPlaybackTranscoding");
            user.policy.enable_video_playback_transcoding = policy_obj.get_boolean_member ("EnableVideoPlaybackTranscoding");
            user.policy.enable_playback_remuxing = policy_obj.get_boolean_member ("EnablePlaybackRemuxing");
            user.policy.force_remote_source_transcoding = policy_obj.get_boolean_member ("ForceRemoteSourceTranscoding");
            user.policy.enable_content_deletion = policy_obj.get_boolean_member ("EnableContentDeletion");

            user.policy.enable_content_deletion_from_folders = new ArrayList<string>();
            for (int i = 0; i < policy_obj.get_array_member ("EnableContentDeletionFromFolders").get_length (); i++) {
                user.policy.enable_content_deletion_from_folders.add (policy_obj.get_array_member ("EnableContentDeletionFromFolders").get_string_element (i));
            }

            user.policy.enable_content_downloading = policy_obj.get_boolean_member ("EnableContentDownloading");
            user.policy.enable_sync_transcoding = policy_obj.get_boolean_member ("EnableSyncTranscoding");
            user.policy.enable_media_conversion = policy_obj.get_boolean_member ("EnableMediaConversion");

            user.policy.enabled_devices = new ArrayList<string>();
            for (int i = 0; i < policy_obj.get_array_member ("EnabledDevices").get_length (); i++) {
                user.policy.enabled_devices.add (policy_obj.get_array_member ("EnabledDevices").get_string_element (i));
            }

            user.policy.enable_all_devices = policy_obj.get_boolean_member ("EnableAllDevices");

            user.policy.enabled_channels = new ArrayList<string>();
            for (int i = 0; i < policy_obj.get_array_member ("EnabledChannels").get_length (); i++) {
                user.policy.enabled_channels.add (policy_obj.get_array_member ("EnabledChannels").get_string_element (i));
            }

            user.policy.enable_all_channels = policy_obj.get_boolean_member ("EnableAllChannels");

            user.policy.enabled_folders = new ArrayList<string>();
            for (int i = 0; i < policy_obj.get_array_member ("EnabledFolders").get_length (); i++) {
                user.policy.enabled_folders.add (policy_obj.get_array_member ("EnabledFolders").get_string_element (i));
            }

            user.policy.enable_all_folders = policy_obj.get_boolean_member ("EnableAllFolders");
            user.policy.invalid_login_attempt_count = (int)policy_obj.get_int_member ("InvalidLoginAttemptCount");
            user.policy.login_attempts_before_lockout = (int)policy_obj.get_int_member ("LoginAttemptsBeforeLockout");
            user.policy.max_active_sessions = (int)policy_obj.get_int_member ("MaxActiveSessions");
            user.policy.enable_public_sharing = policy_obj.get_boolean_member ("EnablePublicSharing");

            user.policy.blocked_media_folders = new ArrayList<string>();
            for (int i = 0; i < policy_obj.get_array_member ("BlockedMediaFolders").get_length (); i++) {
                user.policy.blocked_media_folders.add (policy_obj.get_array_member ("BlockedMediaFolders").get_string_element (i));
            }

            user.policy.blocked_channels = new ArrayList<string>();
            for (int i = 0; i < policy_obj.get_array_member ("BlockedChannels").get_length (); i++) {
                user.policy.blocked_channels.add (policy_obj.get_array_member ("BlockedChannels").get_string_element (i));
            }

            user.policy.remote_client_bitrate_limit = (int)policy_obj.get_int_member ("RemoteClientBitrateLimit");
            user.policy.authentication_provider_id = policy_obj.get_string_member ("AuthenticationProviderId");
            user.policy.password_reset_provider_id = policy_obj.get_string_member ("PasswordResetProviderId");
            user.policy.sync_play_access = policy_obj.get_string_member ("SyncPlayAccess");

            return 0;
        }

    }

}

