function output_name = process_openpose()
clearvars -except output_name

% Modified to accept both JSON and CSV files
[file, path] = uigetfile({'*.CSV;*.JSON;*.csv;*.json','Pose Files (*.CSV,*.JSON)'},'Pick pose data file', 'MultiSelect', 'on');
if isequal(file,0)
    error('No pose file selected');
end

[vid_name, vid_path] = uigetfile({'*.mov;*.mp4;*.avi;*.qt;*.wmv','Video files (*.mov,*.mp4,*.avi,*.qt,*.wmv)'},'Pick original video file');
if isequal(vid_name,0)
    error('No video file selected');
end

[vid_openpose_name, vid_openpose_path] = uigetfile({'*.mov;*.mp4;*.avi;*.qt;*.wmv','Video files (*.mov,*.mp4,*.avi,*.qt,*.wmv)'},'Pick OpenPose labeled video file');
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
    vid_width = str2double(parts{1});
    vid_height = str2double(parts{2});
    fps_parts = strsplit(parts{3}, '/');
    if length(fps_parts) == 2
        sR_openpose = str2double(fps_parts{1}) / str2double(fps_parts{2});
    else
        sR_openpose = str2double(fps_parts{1});
    end
    fprintf('Video properties: %dx%d @ %.2f fps\n', vid_width, vid_height, sR_openpose);
else
    % Fallback to manual input
    vid_width = 640;
    vid_height = 480;
    sR_openpose = 25;
    fprintf('Using default video parameters: %dx%d @ %.2f fps\n', vid_width, vid_height, sR_openpose);
end

vid = struct('Width', vid_width, 'Height', vid_height, 'FrameRate', sR_openpose);
vid_openpose = struct('Width', vid_width, 'Height', vid_height, 'FrameRate', sR_openpose);

videoInfo.vid = vid; 
videoInfo.vid_openpose = vid_openpose;

find_period = find(ismember(vid_name,'.'),1,'last');
output_name = vid_name;
if ~isempty(find_period) && output_name(find_period) == '.'
    output_name(find_period:end) = [];
end

% Check if input is CSV or JSON
if ~iscell(file)
    singleFile = file;
    isCSV = contains(lower(singleFile), '.csv');
else
    isCSV = false;
end

if isCSV
    %% ===== CSV PROCESSING (Your specific format) =====
    fprintf('Processing CSV file with named columns...\n');
    csvData = readtable(fullfile(path, singleFile));
    noFiles = size(csvData, 1);  % Number of rows = number of frames
    
    fprintf('Found %d frames in CSV file\n', noFiles);
    
    % Initialize arrays for BODY_25 format (25 landmarks)
    data = nan(noFiles, noLandmarks, 2);
    conf = ones(noFiles, noLandmarks);  % Default confidence = 1.0
    
    % Map your CSV columns to BODY_25 indices
    % BODY_25 indices (1-based in MATLAB):
    % 1-Nose, 2-Neck, 3-RShoulder, 4-RElbow, 5-RWrist, 6-LShoulder, 7-LElbow, 8-LWrist,
    % 9-MidHip, 10-RHip, 11-RKnee, 12-RAnkle, 13-LHip, 14-LKnee, 15-LAnkle,
    % 16-REye, 17-LEye, 18-REar, 19-LEar, 20-LBigToe, 21-LSmallToe, 22-LHeel,
    % 23-RBigToe, 24-RSmallToe, 25-RHeel
    
    for j = 1:noFiles
        % Index 1: Nose
        data(j, 1, 1) = csvData.NOSE_X(j);
        data(j, 1, 2) = csvData.NOSE_Y(j);
        
        % Index 2: Neck (calculate as midpoint between shoulders)
        if ~isnan(csvData.LEFT_SHOULDER_X(j)) && ~isnan(csvData.RIGHT_SHOULDER_X(j))
            data(j, 2, 1) = (csvData.LEFT_SHOULDER_X(j) + csvData.RIGHT_SHOULDER_X(j)) / 2;
            data(j, 2, 2) = (csvData.LEFT_SHOULDER_Y(j) + csvData.RIGHT_SHOULDER_Y(j)) / 2;
        end
        
        % Index 3: Right Shoulder
        data(j, 3, 1) = csvData.RIGHT_SHOULDER_X(j);
        data(j, 3, 2) = csvData.RIGHT_SHOULDER_Y(j);
        
        % Index 4: Right Elbow
        data(j, 4, 1) = csvData.RIGHT_ELBOW_X(j);
        data(j, 4, 2) = csvData.RIGHT_ELBOW_Y(j);
        
        % Index 5: Right Wrist
        data(j, 5, 1) = csvData.RIGHT_WRIST_X(j);
        data(j, 5, 2) = csvData.RIGHT_WRIST_Y(j);
        
        % Index 6: Left Shoulder
        data(j, 6, 1) = csvData.LEFT_SHOULDER_X(j);
        data(j, 6, 2) = csvData.LEFT_SHOULDER_Y(j);
        
        % Index 7: Left Elbow
        data(j, 7, 1) = csvData.LEFT_ELBOW_X(j);
        data(j, 7, 2) = csvData.LEFT_ELBOW_Y(j);
        
        % Index 8: Left Wrist
        data(j, 8, 1) = csvData.LEFT_WRIST_X(j);
        data(j, 8, 2) = csvData.LEFT_WRIST_Y(j);
        
        % Index 9: Mid Hip (calculate as midpoint between hips)
        if ~isnan(csvData.LEFT_HIP_X(j)) && ~isnan(csvData.RIGHT_HIP_X(j))
            data(j, 9, 1) = (csvData.LEFT_HIP_X(j) + csvData.RIGHT_HIP_X(j)) / 2;
            data(j, 9, 2) = (csvData.LEFT_HIP_Y(j) + csvData.RIGHT_HIP_Y(j)) / 2;
        end
        
        % Index 10: Right Hip
        data(j, 10, 1) = csvData.RIGHT_HIP_X(j);
        data(j, 10, 2) = csvData.RIGHT_HIP_Y(j);
        
        % Index 11: Right Knee
        data(j, 11, 1) = csvData.RIGHT_KNEE_X(j);
        data(j, 11, 2) = csvData.RIGHT_KNEE_Y(j);
        
        % Index 12: Right Ankle
        data(j, 12, 1) = csvData.RIGHT_ANKLE_X(j);
        data(j, 12, 2) = csvData.RIGHT_ANKLE_Y(j);
        
        % Index 13: Left Hip
        data(j, 13, 1) = csvData.LEFT_HIP_X(j);
        data(j, 13, 2) = csvData.LEFT_HIP_Y(j);
        
        % Index 14: Left Knee
        data(j, 14, 1) = csvData.LEFT_KNEE_X(j);
        data(j, 14, 2) = csvData.LEFT_KNEE_Y(j);
        
        % Index 15: Left Ankle
        data(j, 15, 1) = csvData.LEFT_ANKLE_X(j);
        data(j, 15, 2) = csvData.LEFT_ANKLE_Y(j);
        
        % Index 16: Right Eye
        data(j, 16, 1) = csvData.RIGHT_EYE_X(j);
        data(j, 16, 2) = csvData.RIGHT_EYE_Y(j);
        
        % Index 17: Left Eye
        data(j, 17, 1) = csvData.LEFT_EYE_X(j);
        data(j, 17, 2) = csvData.LEFT_EYE_Y(j);
        
        % Index 18: Right Ear
        data(j, 18, 1) = csvData.RIGHT_EAR_X(j);
        data(j, 18, 2) = csvData.RIGHT_EAR_Y(j);
        
        % Index 19: Left Ear
        data(j, 19, 1) = csvData.LEFT_EAR_X(j);
        data(j, 19, 2) = csvData.LEFT_EAR_Y(j);
        
        % Index 20: Left Big Toe (using LEFT_FOOT)
        data(j, 20, 1) = csvData.LEFT_FOOT_X(j);
        data(j, 20, 2) = csvData.LEFT_FOOT_Y(j);
        
        % Index 21: Left Small Toe (not in CSV - leave as NaN)
        % data(j, 21, :) remains NaN
        
        % Index 22: Left Heel
        data(j, 22, 1) = csvData.LEFT_HEEL_X(j);
        data(j, 22, 2) = csvData.LEFT_HEEL_Y(j);
        
        % Index 23: Right Big Toe (using RIGHT_FOOT)
        data(j, 23, 1) = csvData.RIGHT_FOOT_X(j);
        data(j, 23, 2) = csvData.RIGHT_FOOT_Y(j);
        
        % Index 24: Right Small Toe (not in CSV - leave as NaN)
        % data(j, 24, :) remains NaN
        
        % Index 25: Right Heel
        data(j, 25, 1) = csvData.RIGHT_HEEL_X(j);
        data(j, 25, 2) = csvData.RIGHT_HEEL_Y(j);
        
        % Set confidence to 0 for missing data (value = 0.0 or NaN)
        for k = 1:noLandmarks
            if isnan(data(j, k, 1)) || (data(j, k, 1) == 0.0 && data(j, k, 2) == 0.0)
                data(j, k, :) = NaN;
                conf(j, k) = 0;
            end
        end
    end
    
    time_openpose = 0:1/sR_openpose:(noFiles-1)/sR_openpose;
    
    fprintf('CSV data successfully mapped to BODY_25 format\n');
    
else
    %% ===== JSON PROCESSING (Multiple files, one per frame) =====
    fprintf('Processing JSON file(s)...\n');
    
    if iscell(file)
        noFiles = length(file);
        fprintf('Processing %d JSON files (frame-by-frame)\n', noFiles);
    else
        noFiles = 1;
        file = {file};
        fprintf('Processing single JSON file\n');
    end
    
    data = nan(noFiles, noLandmarks, 2);
    conf = nan(noFiles, noLandmarks);
    
    for j = 1:noFiles        
        val = jsondecode(fileread(fullfile(path, file{j})));
        if ~isempty(val.people) && length(val.people) >= 1
            data(j,:,1) = val.people(1).pose_keypoints_2d(1:3:end);
            data(j,:,2) = val.people(1).pose_keypoints_2d(2:3:end);
            conf(j,:) = val.people(1).pose_keypoints_2d(3:3:end);
        end   
    end
    
    time_openpose = 0:1/sR_openpose:(noFiles-1)/sR_openpose;
end

% Ask about walking direction
direction = questdlg('Is the person walking right to left?');
if ~isempty(direction) && strcmp(direction(1), 'Y')
    data(:,:,1) = -data(:,:,1) + vid_width;
end
data(:,:,2) = -data(:,:,2) + vid_height;

% Store data
data_openpose.raw_data = data;
data_openpose.time = time_openpose;
data_openpose.conf = conf;

% Initialize frame info
frameInfo.frames_switch = false(1,noFiles);
frameInfo.frames_leftClear = false(1,noFiles);
frameInfo.frames_rightClear = false(1,noFiles);

% Save output
save(fullfile(cd,[output_name '_openpose.mat']),'data_openpose','videoInfo','output_name','frameInfo')

fprintf('Successfully processed %d frames\n', noFiles);
fprintf('Data saved to: %s\n', fullfile(cd,[output_name '_openpose.mat']));

clearvars -except output_name
end