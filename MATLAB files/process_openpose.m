function output_name = process_openpose()
clearvars -except output_name

% Modified to accept both JSON and CSV files
[file, path] = uigetfile({'*.JSON;*.csv','Pose Files (*.JSON,*.csv)'},'Pick pose data file');
if isequal(file,0)
    error('No pose file selected');
end

[vid_name, vid_path] = uigetfile({'*.mov;*.mp4;*.avi;*.qt;*.wmv','Video files (*.mov,*.mp4,*.avi,*.qt,*.wmv)'},'Pick original video file');
if isequal(vid_name,0)
    error('No original video file selected');
end

[vid_openpose_name, vid_openpose_path] = uigetfile({'*.mov;*.mp4;*.avi;*.qt;*.wmv','Video files (*.mov,*.mp4,*.avi,*.qt,*.wmv)'},'Pick OpenPose labeled video file');
if isequal(vid_openpose_name,0)
    error('No OpenPose video file selected');
end

cd = pwd;
noLandmarks = 25; % BODY_25 model

% Use ffprobe to get video info instead of VideoReader
fprintf('Getting video information using ffprobe...\n');

vid_file = fullfile(vid_path, vid_name);
vid_openpose_file = fullfile(vid_openpose_path, vid_openpose_name);

% Get video properties using ffprobe
cmd = sprintf('ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,duration -of csv=p=0 "%s"', vid_openpose_file);
fprintf('Running command: %s\n', cmd);

[status, cmdout] = system(cmd);

fprintf('Status: %d\n', status);
fprintf('Output: %s\n', cmdout);

if status == 0 && ~isempty(strtrim(cmdout))
    % Parse ffprobe output: width,height,fps,duration
    parts = strsplit(strtrim(cmdout), ',');
    
    if length(parts) >= 3
        width = str2double(parts{1});
        height = str2double(parts{2});
        
        % Parse frame rate (might be in format like "25/1")
        fps_parts = strsplit(parts{3}, '/');
        if length(fps_parts) == 2
            sR_openpose = str2double(fps_parts{1}) / str2double(fps_parts{2});
        else
            sR_openpose = str2double(fps_parts{1});
        end
        
        fprintf('Video properties from ffprobe:\n');
        fprintf('  Resolution: %dx%d\n', width, height);
        fprintf('  Frame rate: %.2f fps\n', sR_openpose);
    else
        error('Unexpected ffprobe output format: %s', cmdout);
    end
else
    % Fallback: ask user for video properties
    fprintf('Warning: ffprobe failed. Status: %d, Output: %s\n', status, cmdout);
    fprintf('Please enter video properties manually:\n');
    
    width = input('Enter video width (pixels) [default 640]: ');
    if isempty(width)
        width = 640;
    end
    
    height = input('Enter video height (pixels) [default 480]: ');
    if isempty(height)
        height = 480;
    end
    
    sR_openpose = input('Enter frame rate (fps) [default 25]: ');
    if isempty(sR_openpose)
        sR_openpose = 25;
    end
end

% Create dummy VideoReader objects for compatibility
vid = struct('Width', width, 'Height', height, 'FrameRate', sR_openpose);
vid_openpose = struct('Width', width, 'Height', height, 'FrameRate', sR_openpose);

fprintf('=== Video Info Set ===\n\n');

videoInfo.vid = vid; videoInfo.vid_openpose = vid_openpose;
find_period = find(ismember(vid_name,'.'),1,'last');
output_name = vid_name;
if output_name(find_period) == '.'
    output_name(find_period:end) = [];
end

% Get number of files from the selected pose file
if iscell(file)
    noFiles = length(file);
else
    % Single JSON file - need to check the structure
    % For now, we'll load it and count frames
    val_test = jsondecode(fileread(fullfile(path,file)));
    if isstruct(val_test) && isfield(val_test, 'people')
        noFiles = 1; % Single frame JSON
    else
        error('Cannot determine number of frames from JSON file');
    end
end

data = nan(noFiles,noLandmarks,2);
conf = nan(noFiles,noLandmarks);
time_openpose = nan(1,noFiles);
       
for j = 1:noFiles        
    if iscell(file)
        current_file = file{j};
    else
        current_file = file;
    end
    val = jsondecode(fileread(fullfile(path,current_file))); % load JSON file
    if ~isempty(val.people) % check if any people are detected
        data(j,:,1) = val.people(1).pose_keypoints_2d(1:3:end);
        data(j,:,2) = val.people(1).pose_keypoints_2d(2:3:end);
        conf(j,:) = val.people(1).pose_keypoints_2d(3:3:end);
    end   
end

direction = questdlg('Is the person walking right to left?');
if direction(1) == 'Y'
    data(:,:,1) = -data(:,:,1) + width; % shift origin and direction of horizontal axis to ensure direction of travel is positive
end
data(:,:,2) = -data(:,:,2) + height; % shift origin and direction of vertical axis from upper corner (positive is down) to lower corner (positive is up)

time_openpose = 0:1/sR_openpose:(noFiles-1)/sR_openpose; % time vector

data_openpose.raw_data = data;
data_openpose.time = time_openpose;
data_openpose.conf = conf;

save(fullfile(cd,[output_name '_openpose.mat']),'data_openpose','videoInfo','output_name')

clearvars -except output_name