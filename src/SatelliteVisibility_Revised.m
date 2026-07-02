%% 1. Define Parameters and Time Setup
queryTime = datetime('now', TimeZone="UTC");
startTime = queryTime - hours(12);
stopTime = queryTime + hours(13);
sampleTime = 60; % seconds

%% 2. Define Ground Stations for Different Environments
areas = [
    -3.4653, -62.2159, 0;  % Amazon Rainforest (Forest Area)
    40.7128, -74.0060, 0;  % Manhattan, New York (Urban Area)
    23.4162, 25.6628, 0;   % Sahara Desert (Non-Urban Area)
];
areaLabels = {'Forest Area', 'Urban Area', 'Non-Urban Area'};
elevationMasks = [30, 25, 10]; % Degrees of minimum elevation angle for each area

%% 3. Load Satellite Data
semAlmanacFileName = "AlmanacFileLocation\\almanacafilename.txt";

%% 4. Initialize Variables to Store Results
gdopValues = [];
posErrors = []; 

%% 5. Loop Through Each Area to Analyze GDOP
for i = 1:length(areas)
    % Extract latitude, longitude, altitude
    lat = areas(i, 1);
    lon = areas(i, 2);
    alt = areas(i, 3);
    minElevation = elevationMasks(i); % Set elevation mask based on environment

    % Create satellite scenario
    sc = satelliteScenario(startTime, stopTime, sampleTime);
    sat = satellite(sc, semAlmanacFileName);

    % Define ground station with specific elevation mask
    gs = groundStation(sc, lat, lon, MinElevationAngle=minElevation);

    % Perform access analysis and calculate GDOP
    allAzimuths = [];
    allElevations = [];
    visibleAzimuths = [];
    visibleElevations = [];

    for j = 1:length(sat)
        [az, el, dist] = aer(gs, sat(j), queryTime);

        % Store all satellite data
        allAzimuths(end+1) = az;
        allElevations(end+1) = el;

        % Filter satellites above the minimum elevation mask
        if el > minElevation
            visibleAzimuths(end+1) = az;
            visibleElevations(end+1) = el;
        end
    end

    % Calculate GDOP if sufficient satellites are visible
    if length(visibleAzimuths) >= 4
        % Generate Geometry Matrix for all visible satellites
        G = zeros(length(visibleAzimuths), 4);
        for k = 1:length(visibleAzimuths)
            G(k, :) = [
                cosd(visibleElevations(k)) * cosd(visibleAzimuths(k)), ...
                cosd(visibleElevations(k)) * sind(visibleAzimuths(k)), ...
                sind(visibleElevations(k)), 1
            ];
        end

        % Calculate GDOP using trace method
        GDOP = sqrt(trace(inv(G' * G)));
        gdopValues(end+1) = GDOP; 
        fprintf('GDOP for %s: %.2f\n', areaLabels{i}, GDOP);
    else
        fprintf('Insufficient satellites visible in %s.\n', areaLabels{i});
        gdopValues(end+1) = NaN; % No valid GDOP
    end

    % Assign hypothetical position errors for plotting
    posErrors(end+1) = 5 * (4 - i); 

    % Plot Satellite Visibility Chart
    figure;
    polarplot(deg2rad(allAzimuths), 90 - allElevations, 'x', 'DisplayName', 'All Satellites'); 
    hold on;
    polarplot(deg2rad(visibleAzimuths), 90 - visibleElevations, 'o', 'DisplayName', 'Visible Satellites');

    % Add mask boundary for visualization
    theta = linspace(0, 2*pi, 360); % Full circle for elevation mask
    maskRadius = 90 - minElevation; % Convert elevation angle to polar radius
    polarplot(theta, repmat(maskRadius, size(theta)), '--r', 'DisplayName', 'Elevation Mask');

    % Customize plot appearance
    title(sprintf('Satellite Visibility: %s', areaLabels{i}));
    legend('show');
    rlim([0, 90]); % Elevation range from 0° to 90°
    hold off;
end

%% 6. Plot GDOP vs Position Error
figure;
scatter(gdopValues, posErrors, 100, 'filled');

% Annotate points with area labels
for i = 1:length(areaLabels)
    text(gdopValues(i) + 0.2, posErrors(i), areaLabels{i}, 'FontSize', 10);
end

% Add labels, title, and grid
xlabel('Geometric Dilution of Precision (GDOP)');
ylabel('Position Error (meters)');
title('Impact of GDOP on Position Errors Across Environments');
grid on;

% Adjust axes for better visibility
xlim([0, max(gdopValues) + 5]);
ylim([0, max(posErrors) + 5]);  
