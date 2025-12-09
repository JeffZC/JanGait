function output_name = process_openpose()
clearvars -except output_name

% Modified to accept both JSON and CSV files
[file, path] = uigetfile({'*.JSON;*.csv','Pose Files (*.JSON,*.csv)'},'Pick pose data file');
if isequal(file,0)
    error('No pose file selected');
end

[vid_name, vid_path] = uigetfile({'*.mov;*.mp4;*.avi;*.qt;*.wmv','Video files (*.mov,*.mp4,*.avi,*.qt,*.wmv)'},'Pick original video file');
if isequal(vid_name,0)
    error('No video file selected');
end

[vid_openpose_name, vid_openpose_path] = uigetfile({'*.mov;*.mp4;*.avi;*.qt;*.wmv','Video files (*.mov,*.mp4,*.avi,*.qt;*.wmv)'},'Pick OpenPose labeled video file');
if isequal(vid_openpose_name,0)
    error('No OpenPose video file selected');
end

cd = pwd;
noLandmarks = 25; % BODY_25 model

% Use ffprobe to get video info
vid_file = fullfile(vid_path, vid_name);
vid_openpose_file = fullfile(vid_openpose_path, vid_openpose_name);

% Get video properties using ffprobe with library path fix
cmd = sprintf('LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "%s"', vid_openpose_file);
[status, cmdout] = system(cmd);

if status == 0 && ~isempty(strtrim(cmdout))
    parts = strsplit(strtrim(cmdout), ',');
    width = str2double(parts{1});
    height = str2double(parts{2});
    fps_parts = strsplit(parts{3}, '/');
    if length(fps_parts) == 2
        sR_openpose = str2double(fps_parts{1}) / str2double(fps_parts{2});
    else
        sR_openpose = str2double(fps_parts{1});
    end
else
    % Fallback to manual input
    width = 640;
    height = 480;
    sR_openpose = 25;
    fprintf('Using default video parameters: %dx%d @ %.2f fps\n', width, height, sR_openpose);
end

vid = struct('Width', width, 'Height', height, 'FrameRate', sR_openpose);
vid_openpose = struct('Width', width, 'Height', height, 'FrameRate', sR_openpose);

videoInfo.vid = vid; 
videoInfo.vid_openpose = vid_openpose;

find_period = find(ismember(vid_name,'.'),1,'last');
output_name = vid_name;
if output_name(find_period) == '.'
    output_name(find_period:end) = [];
end

% Check if input is CSV or JSON
isCSV = contains(lower(file), '.csv');

if isCSV
    % Process CSV file
    csvData = readtable(fullfile(path, file));
    noFiles = height(csvData);  % ← This is line 29
    
    % Initialize arrays
    data = nan(noFiles, noLandmarks, 2);
    conf = ones(noFiles, noLandmarks);
    
    % Map CSV columns to BODY25 format
    for j = 1:noFiles
        % BODY25 index 0: NOSE -> RR21 index 0
        data(j, 1, 1) = csvData.NOSE_X(j);
        data(j, 1, 2) = csvData.NOSE_Y(j);
        
        % BODY25 index 1: NECK (not directly in RR21)
        % Calculate from shoulders as in OpenPose
        data(j, 2, 1) = (csvData.LEFT_SHOULDER_X(j) + csvData.RIGHT_SHOULDER_X(j)) / 2;
        data(j, 2, 2) = (csvData.LEFT_SHOULDER_Y(j) + csvData.RIGHT_SHOULDER_Y(j)) / 2;
        
        % BODY25 index 2: RIGHT_SHOULDER -> RR21 index 6
        data(j, 3, 1) = csvData.RIGHT_SHOULDER_X(j);
        data(j, 3, 2) = csvData.RIGHT_SHOULDER_Y(j);
        
        % BODY25 index 3: RIGHT_ELBOW -> RR21 index 8
        data(j, 4, 1) = csvData.RIGHT_ELBOW_X(j);
        data(j, 4, 2) = csvData.RIGHT_ELBOW_Y(j);
        
        % BODY25 index 4: RIGHT_WRIST -> RR21 index 10
        data(j, 5, 1) = csvData.RIGHT_WRIST_X(j);
        data(j, 5, 2) = csvData.RIGHT_WRIST_Y(j);
        
        % BODY25 index 5: LEFT_SHOULDER -> RR21 index 5
        data(j, 6, 1) = csvData.LEFT_SHOULDER_X(j);
        data(j, 6, 2) = csvData.LEFT_SHOULDER_Y(j);
        
        % BODY25 index 6: LEFT_ELBOW -> RR21 index 7
        data(j, 7, 1) = csvData.LEFT_ELBOW_X(j);
        data(j, 7, 2) = csvData.LEFT_ELBOW_Y(j);
        
        % BODY25 index 7: LEFT_WRIST -> RR21 index 9
        data(j, 8, 1) = csvData.LEFT_WRIST_X(j);
        data(j, 8, 2) = csvData.LEFT_WRIST_Y(j);
        
        % BODY25 index 8: MID_HIP (not directly in RR21)
        % Calculate from hips
        data(j, 9, 1) = (csvData.LEFT_HIP_X(j) + csvData.RIGHT_HIP_X(j)) / 2;
        data(j, 9, 2) = (csvData.LEFT_HIP_Y(j) + csvData.RIGHT_HIP_Y(j)) / 2;
        
        % BODY25 index 9: RIGHT_HIP -> RR21 index 12
        data(j, 10, 1) = csvData.RIGHT_HIP_X(j);
        data(j, 10, 2) = csvData.RIGHT_HIP_Y(j);
        
        % BODY25 index 10: RIGHT_KNEE -> RR21 index 14
        data(j, 11, 1) = csvData.RIGHT_KNEE_X(j);
        data(j, 11, 2) = csvData.RIGHT_KNEE_Y(j);
        
        % BODY25 index 11: RIGHT_ANKLE -> RR21 index 16
        data(j, 12, 1) = csvData.RIGHT_ANKLE_X(j);
        data(j, 12, 2) = csvData.RIGHT_ANKLE_Y(j);
        
        % BODY25 index 12: LEFT_HIP -> RR21 index 11
        data(j, 13, 1) = csvData.LEFT_HIP_X(j);
        data(j, 13, 2) = csvData.LEFT_HIP_Y(j);
        
        % BODY25 index 13: LEFT_KNEE -> RR21 index 13
        data(j, 14, 1) = csvData.LEFT_KNEE_X(j);
        data(j, 14, 2) = csvData.LEFT_KNEE_Y(j);
        
        % BODY25 index 14: LEFT_ANKLE -> RR21 index 15
        data(j, 15, 1) = csvData.LEFT_ANKLE_X(j);
        data(j, 15, 2) = csvData.LEFT_ANKLE_Y(j);
        
        % BODY25 index 15: RIGHT_EYE -> RR21 index 2
        data(j, 16, 1) = csvData.RIGHT_EYE_X(j);
        data(j, 16, 2) = csvData.RIGHT_EYE_Y(j);
        
        % BODY25 index 16: LEFT_EYE -> RR21 index 1
        data(j, 17, 1) = csvData.LEFT_EYE_X(j);
        data(j, 17, 2) = csvData.LEFT_EYE_Y(j);
        
        % BODY25 index 17: RIGHT_EAR -> RR21 index 4
        data(j, 18, 1) = csvData.RIGHT_EAR_X(j);
        data(j, 18, 2) = csvData.RIGHT_EAR_Y(j);
        
        % BODY25 index 18: LEFT_EAR -> RR21 index 3
        data(j, 19, 1) = csvData.LEFT_EAR_X(j);
        data(j, 19, 2) = csvData.LEFT_EAR_Y(j);
        
        % BODY25 index 19: LEFT_BIG_TOE -> RR21 "LEFT_FOOT" (index 19)
        data(j, 20, 1) = csvData.LEFT_FOOT_X(j);
        data(j, 20, 2) = csvData.LEFT_FOOT_Y(j);
        
        % BODY25 index 20: LEFT_SMALL_TOE (not in RR21)
        data(j, 21, 1) = 0;
        data(j, 21, 2) = 0;
        
        % BODY25 index 21: LEFT_HEEL -> RR21 index 17
        data(j, 22, 1) = csvData.LEFT_HEEL_X(j);
        data(j, 22, 2) = csvData.LEFT_HEEL_Y(j);
        
        % BODY25 index 22: RIGHT_BIG_TOE -> RR21 "RIGHT_FOOT" (index 20)
        data(j, 23, 1) = csvData.RIGHT_FOOT_X(j);
        data(j, 23, 2) = csvData.RIGHT_FOOT_Y(j);
        
        % BODY25 index 23: RIGHT_SMALL_TOE (not in RR21)
        data(j, 24, 1) = 0;
        data(j, 24, 2) = 0;
        
        % BODY25 index 24: RIGHT_HEEL -> RR21 index 18
        data(j, 25, 1) = csvData.RIGHT_HEEL_X(j);
        data(j, 25, 2) = csvData.RIGHT_HEEL_Y(j);
    end
    
    % Create time vector based on video frame rate
    time_openpose = 0:1/sR_openpose:(noFiles-1)/sR_openpose;
    
else
    % JSON processing
    if iscell(file)
        noFiles = length(file);
    else
        noFiles = 1;
        file = {file};
    end
    
    data = nan(noFiles, noLandmarks, 2);
    conf = nan(noFiles, noLandmarks);
    
    for j = 1:noFiles        
        val = jsondecode(fileread(fullfile(path,file{j})));
        if ~isempty(val.people)
            data(j,:,1) = val.people(1).pose_keypoints_2d(1:3:end);
            data(j,:,2) = val.people(1).pose_keypoints_2d(2:3:end);
            conf(j,:) = val.people(1).pose_keypoints_2d(3:3:end);
        end   
    end
    
    time_openpose = 0:1/sR_openpose:(noFiles-1)/sR_openpose;
end

direction = questdlg('Is the person walking right to left?');
if direction(1) == 'Y'
    data(:,:,1) = -data(:,:,1) + width;
end
data(:,:,2) = -data(:,:,2) + height;

data_openpose.raw_data = data;
data_openpose.time = time_openpose;
data_openpose.conf = conf;

frameInfo.frames_switch = false(1,noFiles);
frameInfo.frames_leftClear = false(1,noFiles);
frameInfo.frames_rightClear = false(1,noFiles);

save(fullfile(cd,[output_name '_openpose.mat']),'data_openpose','videoInfo','output_name','frameInfo')

clearvars -except output_name
end