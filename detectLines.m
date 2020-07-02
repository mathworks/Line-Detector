classdef detectLines < handle
    % AUTOMATED LINE DETECTOR
    %   DETECTOR = DETECTLINES(IMG) automatically analyzes an input image
    %   and detects lines using a Hough workflow. Output DETECTIONS
    %   contains the begining/endpoints of detections.
    %
    % Binary images are detected directly. Non-binary images are
    % automatically preprocessed first using a generic (but
    % often-successful) set of sequential preprocessing functions.
    %
    % SYNTAX: 
    % 
    % out = detectLines(img, Name, Value)
    %    (All Name-Value pairs are optional.)
    %
    % INPUTS: 
    % 
    % img         % Required; detectLines supports any class of image.
    %
    % fillGap     % Default 20
    %   (See note at discussion; see houghlines)
    %
    % lineProperties % For visualization using displayResults method,
    %   provide a struct containing valid properties of drawline. 
    %      Default:
    %      lineProperties.Color = 'g';
    %      lineProperties.LineWidth = 2;
    %
    % minLength   % Default 40
    %   (See houghlines)
    %
    % NHoodSize   % 2-element vector of positive odd integers; calculated
    %    at runtime based on size of input image. (See houghpeaks)
    %
    % numLines    % Default []
    %   Use this as an alternative to specifying numPeaks and fillGap. If
    %   numLines is specified: threshold is set to 0, fillGap is set to the
    %   diagonal dimension of the input image, and numPeaks is set to
    %   numLines. This is easy syntax, but it provides less flexibility.
    %
    % numPeaks    % Default 1
    %   This is the maximum number of detcted lines that exceed
    %   _threshold_. (See note at numLines; see houghpeaks)
    %
    % preprocessingFcns
    %   You may specify a custom array of function handles, but the final
    %   step should return a binary image. And for best results, it should
    %   likely return an edge-detected binary version!
    %
    %   Binary input images are processed directly. Non-binary images are
    %   automatically preprocessed using:
    %       preprocessingFcns = ...
    %       {@rgb2gray;       % Ignored for grayscale images
    %        @imbinarize;     % Otsu 
    %        @(I) edge(I);}   % Sobel
    %   unless a custom array of preprocessing steps is provided. If a
    %   non-empty set of preprocessing steps does not result in a binary
    %   img, the final result will be automatically converted with
    %   @imbinarize. (Hough requires a binary image.)
    %
    % rhoResolution  %Spacing of Hough transform bins; Default 1.
    %   (See hough)
    %
    % thetaMax    % Maximum value of theta in call to hough. Default 89.
    %   (See hough)
    %
    % thetaMin    % Minimum value of theta in call to hough. Default -90.
    %   (See hough)
    %
    % thetaStep    % Minimum value to be considered a peak, specified as a
    %   nonnegative number. Calculated at runtime based on hough matrix.
    %   Default 1. (See houghpeaks)
    %
    % threshold    % Threshold for peak detection in houghpeaks. Default is
    %   calculated at runtime, based on value of Hough transform. (See note
    %   at discussion of numLines.)
    %
    % OUTPUT:
    %
    %   detections  % A struct, the fields of which contain (IN ADDITION TO
    %      input properties and all values returned by hough, houghpeaks,
    %      and houghlines):
    %
    %      'lines' % The output of houghlines. (See houghlines)
    %
    %      'handles' % Handles to line objects (created using drawlines).
    %         Note that this field is populated only after calling
    %         'displayResults' method.
    %
    % METHODS: 
    %
    % detect
    %   Call, or re-call, detection algorithm. |detect| is called on
    %   instantiation of the detector. You may subsequently re-detect using
    %   different properties by passing in the returned detector. (See
    %   example 1a below.)
    %
    % displayResults
    %   Create images.roi.Line object(s) (using drawline). Calling this
    %   method populates the output field 'handles'.)
    %
    % tuneInteractively
    %   Simply passes processedImg into the segmentImage() app and
    %   activates the Hough Transform panel. If you don't have the app, you
    %   will be prompted to download/install it.
    %
    % % EXAMPLES
    %
    % % Example 1: Gantry Crane
    %
    % img = imread('gantrycrane.png'); 
    % imshow(img) 
    % detections = detectLines(img, ...
    %    'numPeaks', 10, ... 
    %    'minLength', 100, ... 
    %    'NHoodSize', [51 51],... 
    %    'threshold', 1);
    % displayResults(detections)
    %
    % % Example 1a: Modify, re-detect: 
    % detections.thetaMin = -20;
    % detections.thetaMax = 60;
    % % Note: re-calling |displayResults| resets detections.handles!
    % detections = detect(detections);
    % set(detections.handles, 'Color', 'r')
    % displayResults(detections)
    %
    % % Example 2: bricksRotated: specifying numLines
    %
    % img = imread('bricksRotated.jpg');
    % imshow(img)
    % detections = detectLines(img, ...
    %    'numLines', 14);
    % displayResults(detections)
    %
    % % Example 2a: Tune interactively
    % img = imread('bricksRotated.jpg');
    % imshow(img)
    % detections = detectLines(img);
    % tuneInteractively(detections)
    %
    % % Example 2b: Specifying preprocessing and display options
    %
    % img = imread('bricksRotated.jpg');
    % imshow(img)
    % detections = detectLines(img, ...
    %    'preprocessingFcns', ...
    %       {@imbinarize;
    %        @(I)edge(I,'LOG');
    %        @(I)bwareaopen(I, 50)}, ...
    %    'fillGap', 100, ... 
    %    'threshold', 1, ... 
    %    'numPeaks', 14);
    % lineOpts.Color = 'r';
    % lineOpts.LineWidth = 3;
    % displayResults(detections, lineOpts)
    %
    % Brett Shoelson, PhD
    % bshoelso@mathworks.com
    % 06/26/2020
    %
    % See also hough houghlines houghpeaks
    
    % Copyright 2020 The MathWorks, Inc.
    
    properties
        fillGap
        handles
        HoughTransform
        img
        lineProperties
        lines % CONTAINS OUTPUT OF HOUGHLINES
        minLength
        NHoodSize %[m, n]
        numLines
        numPeaks
        peaks
        preprocessingFcns
        processedImg
        rho
        rhoResolution
        theta
        thetaMax
        thetaMin
        thetaStep
        threshold
    end
    
    methods
        % INSTANTIATE:
        function lineDetector = detectLines(img, varargin)
            % Implement input arguments
            [lineDetector.fillGap, ...
                lineDetector.minLength, lineDetector.NHoodSize, ...
                lineDetector.numLines, lineDetector.numPeaks, ...
                lineDetector.preprocessingFcns, ...
                lineDetector.rhoResolution, ...
                lineDetector.thetaMax, lineDetector.thetaMin, ...
                lineDetector.thetaStep, lineDetector.threshold] = ...
                parseInputs(varargin{:});
            % PREPROCESS
            lineDetector.img = img;
            preprocessedImg = preprocess(img, lineDetector);
            lineDetector.processedImg = preprocessedImg;
            
            function [fillGap, minLength, NHoodSize, ...
                    numLines, numPeaks, preprocessingFcns, rhoResolution, ...
                    thetaMax, thetaMin, thetaStep, threshold] = ...
                    parseInputs(varargin)
                % Setup parser with defaults
                parser = inputParser;
                parser.CaseSensitive = false;
                parser.addParameter('fillGap', 20);
                parser.addParameter('minLength', 40);
                parser.addParameter('NHoodSize', []);
                parser.addParameter('numLines', []);
                parser.addParameter('numPeaks', 1);
                processFcns = {@rgb2gray;
                    @imbinarize;
                    @(I) edge(I, 'LOG')};
                parser.addParameter('preprocessingFcns', processFcns);
                parser.addParameter('rhoResolution', 1);
                parser.addParameter('thetaMax', 89);
                parser.addParameter('thetaMin', -90);
                parser.addParameter('thetaStep', 1);
                parser.addParameter('threshold', []);
                % Parse input
                parser.parse(varargin{:});
                % Assign outputs
                r = parser.Results;
                [fillGap, minLength, NHoodSize, numLines, ...
                    numPeaks, preprocessingFcns, rhoResolution, ...
                    thetaMax, thetaMin, thetaStep, threshold] = ...
                    deal(r.fillGap, r.minLength, r.NHoodSize, r.numLines, ...
                    r.numPeaks, r.preprocessingFcns, r.rhoResolution, ...
                    r.thetaMax, r.thetaMin, r.thetaStep, r.threshold);
            end
            % DETECT
            lineDetector = detect(lineDetector);
        end
        %
    end
    
    methods (Access = public)
        function lineDetector = detect(lineDetector)
            thisImg = lineDetector.processedImg;
            % DETECT LINES:
            [lineDetector.HoughTransform, lineDetector.theta, lineDetector.rho] = ...
                hough(thisImg,...
                'Theta', lineDetector.thetaMin : lineDetector.thetaStep : lineDetector.thetaMax, ...
                'RhoResolution',lineDetector.rhoResolution);
            if isempty(lineDetector.NHoodSize)
                % The default value of NHoodSize is the smallest odd values
                %   greater than or equal to size(HoughTransform)/50
                lineDetector.NHoodSize = size(lineDetector.HoughTransform)/50;
                % Make sure the nhood size is odd:
                lineDetector.NHoodSize = max(2*ceil(lineDetector.NHoodSize/2) + 1, 1);
            end
            %
            if ~isempty(lineDetector.numLines)
                lineDetector.threshold = 0;
                [m,n] = size(lineDetector.processedImg);
                lineDetector.fillGap = ceil(sqrt(m^2 + n^2));
                lineDetector.numPeaks = lineDetector.numLines;
            end
            if isempty(lineDetector.threshold)
                thisThreshold = 0.5*max(lineDetector.HoughTransform(:));
                lineDetector.threshold = thisThreshold;
            else
                thisThreshold = lineDetector.threshold;
            end
            lineDetector.peaks = houghpeaks(lineDetector.HoughTransform, ...
                lineDetector.numPeaks, ...
                'threshold', thisThreshold, ...
                'NHoodSize',lineDetector.NHoodSize);
            %%%
            % Validated that lineDetector.peaks == tmpPeaks when no input
            %    arguments are provided for the former.
            % tmpPeaks = houghpeaks(lineDetector.HoughTransform);
            %%%
            lineDetector.lines = houghlines(thisImg, ...
                lineDetector.theta, ...
                lineDetector.rho, ...
                lineDetector.peaks, ...
                'FillGap', lineDetector.fillGap, ...
                'MinLength', lineDetector.minLength);
        end %detect
        %
        function displayResults(lineDetector, lineProperties)
            if nargin < 2 || isempty(lineProperties)
                lineProperties.Color = 'g';
                lineProperties.LineWidth = 2;
            end
            lineDetector.lineProperties = lineProperties;
            lineDetector.handles = gobjects(size(lineDetector.lines,2), 1);
            for ii = 1:numel(lineDetector.handles)
                thisPosition = [lineDetector.lines(ii).point1;
                    lineDetector.lines(ii).point2];
                lineDetector.handles(ii) = drawline('Position', thisPosition, ...
                    lineProperties);
            end
            fprintf('%i Lines displayed.\n', numel(lineDetector.handles));
        end
        %
        function tuneInteractively(lineDetector)
            % 
            try
                drawnow
                segtoolHndl = segmentImage(lineDetector.processedImg);
                drawnow %Force completion; app is opening in partial state
            catch
                beep
                s1 = sprintf('\nNOTE:\nInteractive tuning requires the segmentImage() app. It appears\nthat you don''t have it!. Please first download and install\n');
                s2 = sprintf('<a href="matlab: web(''https://www.mathworks.com/matlabcentral/fileexchange/48859-segment-images-interactively-and-generate-matlab-code'')">segmentImage</a> from the MATLAB Central File Exchange.\n\n');
                fprintf('\ndetectLines: Method unavailable.\n%s%s',s1,s2)
                return
            end
            % Activate Hough Panel:
            %tabPanel(tabCardHandles,tabHandles{tier}(tabRank,:))
            mainTabPanel = findall(segtoolHndl, ...
                'type','UiPanel', 'tag', 'mainTabPanel');
            tabCardHandles = getappdata(segtoolHndl, 'mainTabCardHandles');
            tabHandles = getappdata(mainTabPanel, 'tabHandles');
            houghTab = tabHandles{1}(3);
            tabPanel(tabCardHandles, houghTab);
%             % Set values:
%             houghCardHandle = tabCardHandles{1}(3);
%             allHndls = findall(houghCardHandle);
%             tmp = findall(allHndls, 'Tag', 'HoughLinesMinLength');
%             set(tmp, 'string', lineDetector.minLength);
%             tmp = findall(allHndls, 'Tag', 'HoughLinesFillGap');
%             set(tmp, 'string', lineDetector.fillGap);
%             tmp = findall(allHndls, 'Tag', 'HoughNHoodSize1');
%             set(tmp, 'string', lineDetector.NHoodSize(1));
%             tmp = findall(allHndls, 'Tag', 'HoughNHoodSize2');
%             set(tmp, 'string', lineDetector.NHoodSize(2));
%             tmp = findall(allHndls, 'Tag', 'NumPeaksSldr');
%             set(tmp, 'Value', lineDetector.numPeaks);
%             tmp = findall(allHndls, 'Tag', 'ThetaResSldr');
%             set(tmp, 'Value', lineDetector.thetaStep);
%             tmp = findall(allHndls, 'Tag', 'ThetaMinSldr');
%             set(tmp, 'Value', lineDetector.thetaMin);
%             tmp = findall(allHndls, 'Tag', 'ThetaMaxSldr');
%             set(tmp, 'Value', lineDetector.thetaMax, ...
%                 'string', num2str(lineDetector.thetaMax));
%             tmp = findall(allHndls, 'Tag', 'HoughPeakThresh');
%             set(tmp, 'Value', lineDetector.threshold);
%             tmp = findall(allHndls, 'Tag', 'ThetaResSldr');
%             set(tmp, 'Value', 4, 'string', '4');
%             rhoResolution
%             feval(tmp(1).Callback)
        end
    end
    
    methods (Access = private)
        function processedImg = preprocess(img, lineDetector)
            % First: Is the image already logical? (Hough works on binary
            % images--and works BEST on edge-detected binary images.)
            if ~islogical(img)
                % Preprocessing:
                % (DEFAULT:)
                % processFcns = {@rgb2gray;
                %    @imbinarize;
                %    @(I) edge(I, 'LOG')};
                lineDetector.processedImg = lineDetector.img;
                for ii = 1:numel(lineDetector.preprocessingFcns)
                    thisFcn = lineDetector.preprocessingFcns{ii};
                    try
                        lineDetector.processedImg = thisFcn(lineDetector.processedImg);
                    catch
                        str = func2str(thisFcn);
                        if strcmp(str, 'rgb2gray') && size(lineDetector.processedImg, 3) ~= 3
                            continue
                        else
                            fprintf('Unable to apply function ''%s''.\n', str);
                        end
                    end
                end
            end
            
            if ~islogical(lineDetector.processedImg)
                % DEFAULT binarization/edge
                lineDetector.processedImg = imbinarize(lineDetector.processedImg);
            end
            processedImg = lineDetector.processedImg;
        end
    end
    
    methods (Static)
        % This is required by handle class
        function pos = getPosition()
            pos = [];
        end
    end
    
end

