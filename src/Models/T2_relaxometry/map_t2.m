classdef map_t2 < AbstractModel % Name your Model
    % vfa_t1: Compute a T1 map using Variable Flip Angle
    %
    % Assumptions:
    %
    % Inputs:
    %   MESEdata         spoiled Gradient echo data, 4D volume with different flip angles in time dimension
    %   (Mask)          Binary mask to accelerate the fitting (optional)
    %
    % Outputs:
    %   T2              Transverse relaxation time [s]
    %   M0              Equilibrium magnetization
    %
    % Protocol:
    %   VFAData Array [nbFA x 2]:
    %       [FA1 TR1; FA2 TR2;...]      flip angle [degrees] TR [s]
    %
    % Options:
    %   None
    %
    % Example of command line usage:
    %   Model = vfa_t1;  % Create class from model
    %   Model.Prot.VFAData.Mat=[3 0.015; 20 0.015]; %Protocol: 2 different FAs
    %   data = struct;  % Create data structure
    %   data.VFAData = load_nii_data('VFAData.nii.gz');
    %   data.B1map = load_nii_data('B1map.nii.gz');
    %   FitResults = FitData(data,Model); %fit data
    %   FitResultsSave_mat(FitResults);
    %
    %   For more examples: <a href="matlab: qMRusage(vfa_t1);">qMRusage(vfa_t1)</a>
    
    
    
    properties
        MRIinputs = {'MESEdata','Mask'}; % used in the data panel
        
        % fitting options
        xnames = { 'T2','M0','Offset'}; % name of the parameters to fit
        voxelwise = 1; % 1--> input data in method 'fit' is 1D (vector). 0--> input data in method 'fit' is 4D.
        %st           = [ 0.7	0.5 ]; % starting point
        %lb            = [  0      0 ]; % lower bound
        %ub           = [ 1        3 ]; % upper bound
        %fx            = [ 0       0 ]; % fix parameters
        
        % Protocol
        Prot  = struct('MESEdata',struct('Format',{{'EchoTime (ms)'}},...
            'Mat', [10; 20; 30; 40; 50; 60; 70; 80; 90; 100; 110; 120; 130; 140; 150; 160; 170;
            180; 190; 200; 210; 220; 230; 240; 250; 260; 270; 280; 290; 300; 310; 320]));
        
        % Model options
        buttons = {'FitType',{'Linear','Exponential'},'DropFirstEcho',false,'OffsetTerm',false,'Cutoff', 40};
        options= struct();
        
    end
    
    methods
        
        function obj = map_t2()
            
            obj.options = button2opts(obj.buttons);
            
        end
        
        function Smodel = equation(obj, x)
            x = mat2struct(x,obj.xnames); % if x is a structure, convert to vector
            
            % equation
            Smodel = x.M0.*exp(-obj.Prot.MESEdata.Mat./x.T2);
        end
        
        function FitResults = fit(obj,data)
            %  Fit data using model equation.
            %  data is a structure. FieldNames are based on property
            %  MRIinputs.
            
            if strcmp(obj.options.FitType,'Exponential')
                % Non-linear least squares using <<levenberg-marquardt (LM)>>
                
                
                if obj.options.DropFirstEcho
                    
                    xData = obj.Prot.MESEdata.Mat(2:end);
                    yDat = data.MESEdata(2:end);
                    
                    
                    
                    if max(size(yDat)) == 1
                        error('DropFirstEcho is not valid for ETL of 2.');
                    end
                    
                else
                   
                    xData = obj.Prot.MESEdata.Mat;
                    yDat = data.MESEdata;
                 
                end
                
                %xData = xData';
                
                if obj.options.OffsetTerm
                    fT2 = @(a)(a(1)*exp(-xData/a(2)) + a(3)  - yDat);
                else
                    fT2 = @(a)(a(1)*exp(-xData/a(2)) - yDat);
                end
                
                yDat = abs(yDat);
                yDat = yDat./max(yDat);
                
                % T2 initialization adapted from
                % https://github.com/blemasso/FLI_pipeline_T2/blob/master/matlab/pipeline_T2.m
                
                t2Init_dif = xData(1) - xData(end-1);
                t2Init = t2Init_dif/log(yDat(end-1)/yDat(1));
                
                if t2Init<=0 || isnan(t2Init),
                    t2Init=30;
                end
                
                pdInit = max(yDat(:))*1.5;
                
                options = struct();
                options.Algorithm = 'levenberg-marquardt';
                options.Display = 'off';
                
                if obj.options.OffsetTerm
                    fit_out = lsqnonlin(fT2,[pdInit t2Init 0],[],[],options);
                else
                    fit_out = lsqnonlin(fT2,[pdInit t2Init],[],[],options);
                end
                
                FitResults.T2 = fit_out(2);
                FitResults.M0 = fit_out(1);
                
                
            else
                % Linearize solution with <<log transformation (LT)>>
                
                if obj.options.DropFirstEcho
                    
                    xData = obj.Prot.MESEdata.Mat(2:end);
                    yDat = log(data.MESEdata(2:end));
                    
                    if max(size(yDat)) == 1
                        error('DropFirstEcho is not valid for ETL of 2.');
                    end
                    
                    else
                   
                    xData = obj.Prot.MESEdata.Mat;
                    yDat = log(data.MESEdata);
                    
                end
                
                regOut = [ones(size(xData)),xData] \ yDat;
                
                fit_out(1) = exp(regOut(1));
                if regOut(2) == 0 ; regOut(2) = eps; end;
                t2 = -1./regOut(2);
                
                if t2>obj.options.Cutoff; t2 = obj.options.Cutoff; end;
                if isnan(t2); t2 = 0; end;
                if t2<0; t2 = 0; end;
                
                FitResults.T2 = t2;
                FitResults.M0 = fit_out(1);
                
                
            end
            %  convert fitted vector xopt to a structure.
            %FitResults = cell2struct(mat2cell(xopt(:),ones(length(xopt),%1)),obj.xnames,1);
            %FitResults.resnorm=resnorm;
            
        end
        
        
        function plotModel(obj, FitResults, data)
            %  Plot the Model and Data.
            if nargin<2, qMRusage(obj,'plotModel'), FitResults=obj.st; end
            
            %Get fitted Model signal
            Smodel = equation(obj, FitResults);
            
            %Get the varying acquisition parameter
            Tvec = obj.Prot.MESEdata.Mat;
            [Tvec,Iorder] = sort(Tvec);
            
            % Plot Fitted Model
            plot(Tvec,Smodel(Iorder),'b-')
            
            % Plot Data
            if exist('data','var')
                hold on
                plot(Tvec,data.MESEdata(Iorder),'r+')
                hold off
            end
            legend({'Model','Data'})
        end
        
        function FitResults = Sim_Single_Voxel_Curve(obj, x, Opt, display)
            % Compute Smodel
            Smodel = equation(obj, x);
            % add rician noise
            sigma = max(Smodel)/Opt.SNR;
            data.MESEdata = random('rician',Smodel,sigma);
            % fit the noisy synthetic data
            FitResults = fit(obj,data);
            % plot
            if display
                plotModel(obj, FitResults, data);
            end
        end
        
    end
end