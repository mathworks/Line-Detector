classdef detectLines < handle
    % AUTOMATED LINE DETECTOR
    %   DETECTOR = DETECTLINES(IMG) automatically analyzes an input image and
    %   detects lines using a Hough workflow. Output DETECTIONS contains the
    %   begining/endpoints of detections.
    %   lineDetectorect.
    %
    % % EXAMPLES
    %
    % % Example 1: Gantry Crane
    %
    % img = imread('gantrycrane.png');
    % imshow(img)
    % myLines = detectLines(img, ...
    %    'numPeaks', 10, ...
    %    'minLength', 100, ...
    %    'NHoodSize', [51 51], ...    
    %    'threshold', 1);
    % displayDetections(myLines)
    % % Modify, re-detect:
    % myLines.thetaMin = -20;
    % myLines.thetaMax = 60;
    % myLines = detect(myLines);
    % % Note: this resets myLines.handles!
    % lineOpts.Color = 'r';
    % lineOpts.LineWidth = 3;
    % displayDetections(myLines, lineOpts)
    % lineOpts.Color = 'r';
    % lineOpts.LineWidth = 3;
    % displayDetections(myLines, lineOpts)
    %
    % preprocessingFcns = ...
    %   {@(x) imadjust(x,[0.20; 0.30],[0.00; 1.00],1.00);
    %    @(x) imcomplement(x);
    %    @(x) edge(x,'LOG',0.015,2.00)};
    %
    % figure
    % imshow(img)
    % detections = detectLines(img);
    %
    % Brett Shoelson, PhD
    % bshoelso@mathworks.com
    % 06/26/2020
    %
    % See also hough houghlines houghpeaks
    
    % Copyright 2020 The MathWorks, Inc.
    
    properties
        detections %OUTPUT STRUCT
        fillGap
        handles 
        HoughTransform
        img
        lineProperties
        minLength
        NHoodSize %[m, n]
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
                lineDetector.numPeaks, lineDetector.preprocessingFcns, ...
                lineDetector.rhoResolution, ...
                lineDetector.thetaMax, lineDetector.thetaMin, ...
                lineDetector.thetaStep, lineDetector.threshold] = ...
                parseInputs(varargin{:});
            % PREPROCESS
            lineDetector.img = img;
            preprocessedImg = preprocess(img, lineDetector);
            lineDetector.processedImg = preprocessedImg;

            function [fillGap, minLength, NHoodSize, ...
                numPeaks, preprocessingFcns, rhoResolution, ...
                thetaMax, thetaMin, thetaStep, threshold] = ...
                parseInputs(varargin)
                % Setup parser with defaults
                parser = inputParser;
                parser.CaseSensitive = false;
                parser.addParameter('fillGap', 20);
                parser.addParameter('minLength', 40);
                parser.addParameter('NHoodSize', []);
                parser.addParameter('numPeaks', 1);
                parser.addParameter('preprocessingFcns', {});
                parser.addParameter('rhoResolution', 1);
                parser.addParameter('thetaMax', 89);
                parser.addParameter('thetaMin', -90);
                parser.addParameter('thetaStep', 1);
                parser.addParameter('threshold', []);
                % Parse input
                parser.parse(varargin{:});
                % Assign outputs
                r = parser.Results;
                [fillGap, minLength, NHoodSize, ...
                numPeaks, preprocessingFcns, rhoResolution, ...
                thetaMax, thetaMin, thetaStep, threshold] = ...
                deal(r.fillGap, r.minLength, r.NHoodSize, ...
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
                'Theta',lineDetector.thetaMin : lineDetector.thetaStep : lineDetector.thetaMax, ...
                'RhoResolution',lineDetector.rhoResolution);
            if isempty(lineDetector.NHoodSize)
                % The default value of NHoodSize is the smallest odd values
                %   greater than or equal to size(HoughTransform)/50
                lineDetector.NHoodSize = size(lineDetector.HoughTransform)/50;
                % Make sure the nhood size is odd:
                lineDetector.NHoodSize = max(2*ceil(lineDetector.NHoodSize/2) + 1, 1);
            end
            %
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
           lineDetector.detections = houghlines(thisImg, ...
                lineDetector.theta, ...
                lineDetector.rho, ...
                lineDetector.peaks, ...
                'FillGap', lineDetector.fillGap, ...
                'MinLength', lineDetector.minLength);
        end %detect
        %
        function displayDetections(lineDetector, lineProperties)
            if nargin < 2 || isempty(lineProperties)
                lineProperties.Color = 'g';
                lineProperties.LineWidth = 2;
            end
            lineDetector.lineProperties = lineProperties;
            lineDetector.handles = gobjects(size(lineDetector.detections,2), 1);
            for ii = 1:numel(lineDetector.handles)
                thisPosition = [lineDetector.detections(ii).point1;
                    lineDetector.detections(ii).point2];
                lineDetector.handles(ii) = drawline('Position', thisPosition, ...
                    lineProperties);
            end
        end
    end
    
    methods (Access = private)
        function processedImg = preprocess(img, lineDetector)
            % First: Is the image already logical? (Hough works on binary
            % images--and works BEST on edge-detected binary images.)
            if size(img, 3) == 3
                lineDetector.processedImg = im2gray(img); % Requires R2020b+
            else
                lineDetector.processedImg = img;
            end
            %  Preprocess
            for ii = 1:numel(lineDetector.preprocessingFcns)
                lineDetector.processedImg = feval(lineDetector.preprocessingFcns{ii}, ...
                    lineDetector.processedImg);
            end
            if ~islogical(lineDetector.processedImg)
                % DEFAULT binarization/edge 
                lineDetector.processedImg = imbinarize(lineDetector.processedImg);
                lineDetector.processedImg = edge(lineDetector.processedImg, 'LOG'); 
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

