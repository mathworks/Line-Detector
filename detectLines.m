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
    % out = detectLines(img, Name, Value)
    %   (All Name-Value pairs are optional.)
    %
    % INPUTS: 
    % img         % Required; detectLines supports any class of image.
    %
    % fillGap     % Default 20
    %   (See houghlines)
    %
    % lineProperties % For visualization using display method,
    %   provide a struct containing valid properties of drawline.
    %   Default:
    %      lineProperties.Color = 'g';
    %      lineProperties.LineWidth = 2;
    %
    % minLength   % Default 40
    %   (See houghlines)
    %
    % NHoodSize   % 2-element vector of positive odd integers; calculated
    %    at runtime based on size of input image.
    %   (See houghpeaks)
    %
    % numPeaks    % Default 1
    %   This is the maximum number of detcted lines that exceed
    %   _threshold_. (See houghpeaks)
    %
    % preprocessingFcns    
    %   You may specify a custom array of function handles, but the final
    %   step should return a binary image. And for best results, it should
    %   likely return an edge-detected binary version! Binary input images
    %   are processed directly. Non-binary images are automatically
    %   preprocessed using:
    %       preprocessingFcns = {@im2gray;        % Requires R2020b+; RGB2GRAY may be substituted
    %                            @imbinarize;     % Otsu
    %                            @(I) edge(I);}   % Sobel
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
    % OUTPUT: 
    %   detections  % A struct, the fields of which contain (IN ADDITION TO
    %      input properties and all values returned by hough, houghpeaks,
    %      and houghlines):
    %  
    %      'lines' % The output of houghlines. (See houghlines)
    % 
    %      'handles' % Handles to line objects (created using drawlines).
    %      Note that this field is populated only after calling 'display'
    %      method.
    % 
    %
    % METHODS:
    % detect
    %   Call, or Re-call, detection algorithm. |detect| is called on
    %   instantiation of the detector. You may subsequently re-detect using
    %   different properties by passing in the returned detector. (See
    %   example 1a below.)
    %
    % display
    %   Create images.roi.Line object(s) (using drawline). Calling this
    %   method populates the output field 'handles'.)
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
    %    'NHoodSize', [51 51], ...    
    %    'threshold', 1);
    % display(detections)
    % 
    % % Example 1a: Modify, re-detect:
    % detections.thetaMin = -20;
    % detections.thetaMax = 60;
    % detections = detect(detections);
    % set(detections.handles, 'Color', 'r')
    % % Note: this resets detections.handles!
    % display(detections)
    %
    % % Example 2: bricksRotated
    %
    % img = imread('bricksRotated.jpg');
    % imshow(img)
    % detections = detectLines(img, ...
    %  'fillGap', 100, ...
    %  'threshold', 1, ...
    %  'numPeaks', 14);
    % display(detections)
    %
    % % Example 2a: Specifying preprocessing and display options
    % 
    % img = imread('bricksRotated.jpg');
    % imshow(img)
    % detections = detectLines(img, ...
    %  'preprocessingFcns', ...
    %     {@imbinarize;
    %      @(I)edge(I,'LOG');
    %      @(I)bwareaopen(I, 50)}, ...
    %  'fillGap', 100, ...
    %  'threshold', 1, ...
    %  'numPeaks', 14);
    % lineOpts.Color = 'r';
    % lineOpts.LineWidth = 3;
    % display(detections, lineOpts)
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
                processFcns = {@im2gray;
                    @(I) imfill(I, 'holes');
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
           lineDetector.lines = houghlines(thisImg, ...
                lineDetector.theta, ...
                lineDetector.rho, ...
                lineDetector.peaks, ...
                'FillGap', lineDetector.fillGap, ...
                'MinLength', lineDetector.minLength);
        end %detect
        %
        function display(lineDetector, lineProperties)
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
        end
    end
    
    methods (Access = private)
        function processedImg = preprocess(img, lineDetector)
            % First: Is the image already logical? (Hough works on binary
            % images--and works BEST on edge-detected binary images.)
            if ~islogical(img)
            %  Preprocess
                lineDetector.processedImg = ...
                    applyFunctionHandles(img, lineDetector.preprocessingFcns);
            else
                lineDetector.processedImg = img;
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

