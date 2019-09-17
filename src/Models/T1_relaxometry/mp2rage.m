classdef mp2rage < AbstractModel
% mp2rage: Compute a T1 map using MP2RAGE
%
% Assumptions:
%
% Inputs:
%   MP2RAGE_UNI         spoiled Gradient echo data, 4D volume with different flip angles in time dimension
%   (Mask)          Binary mask to accelerate the fitting (optional)
%
% Outputs:
%   T1              Longitudinal relaxation time [s]
%   R1              Equilibrium magnetization
%

properties (Hidden=true)
 onlineData_url = 'https://osf.io/8x2c9/download?version=2';  
end

    properties
        MRIinputs = {'MP2RAGE', 'Mask'};
        xnames = {'T1','R1'};
        voxelwise = 0;
        
        % Protocol
        Prot  = struct(); % You can define a default protocol here.

        % Model options
        buttons = {'B0 (T)', 7, ...
                   'Inversion TR (s)', 6, ...
                   'Excitation TR (s)', 6.7e-3, ...
                   'Inversion times (s)', [800e-3 2700e-3], ...
                   'Flip angles', [4 5], ...
                   'Number of shots' [35 72], ...
                   'Inv efficiency', 0.96};
        options= struct(); % structure filled by the buttons. Leave empty in the code
    end

methods (Hidden=true)
% Hidden methods goes here.
end

    methods

        function obj = mp2rage()
            obj.options = button2opts(obj.buttons);
        end

        function Smodel = equation(obj,x)
            % Generates a VFA signal based on input parameters
            x = mat2struct(x,obj.xnames); % if x is a structure, convert to vector

            % Equation: S=M0sin(a)*(1-E)/(1-E)cos(a); E=exp(-TR/T1)
            flipAngles = (obj.Prot.VFAData.Mat(:,1))';
            TR = obj.Prot.VFAData.Mat(1,2);
            E = exp(-TR/x.T1);
            Smodel = x.M0*sin(flipAngles/180*pi)*(1-E)./(1-E*cos(flipAngles/180*pi));
        end

       function FitResult = fit(obj,data)
           
           opts.MagneticFieldStrength = obj.options.B0T;
           opts.RepetitionTimeInversion = obj.options.InversionTRs;
           opts.RepetitionTimeExcitation = obj.options.ExcitationTRs;
           opts.InversionTime = obj.options.Inversiontimess;
           opts.FLipAngle = obj.options.Flipangles;
           opts.NumberShots = obj.options.Numberofshots;
           opts.invEFF = obj.options.Invefficiency;
           
           MagneticFieldStrength = 7;
           RepetitionTimeInversion = 6;
           RepetitionTimeExcitation = 6.7e-3;
           InversionTime = [800e-3 2700e-3];
           FlipAngle = [4 5];
           NumberShots = [35 72];
           invEFF = 0.96;

           MP2RAGE.B0 = MagneticFieldStrength;           % in Tesla
           MP2RAGE.TR = RepetitionTimeInversion;           % MP2RAGE TR in seconds
           MP2RAGE.TRFLASH = RepetitionTimeExcitation; % TR of the GRE readout
           MP2RAGE.TIs = InversionTime; % inversion times - time between middle of refocusing pulse and excitatoin of the k-space center encoding
           MP2RAGE.NZslices = NumberShots; % Excitations [before, after] the k-space center
           MP2RAGE.FlipDegrees = FlipAngle; % Flip angle of the two readouts in degrees

           
           assertEqual(opts.MagneticFieldStrength, MP2RAGE.B0)
           assertEqual(opts.RepetitionTimeInversion, MP2RAGE.TR)
           assertEqual(opts.RepetitionTimeExcitation, MP2RAGE.TRFLASH)
           assertEqual(opts.InversionTime, InversionTime)
           assertEqual(opts.FLipAngle, FlipAngle)
           assertEqual(opts.NumberShots, NumberShots)
           assertEqual(opts.invEFF, invEFF)
           
           MP2RAGEimg.img = data.MP2RAGE;

           [T1map, R1map]=T1estimateMP2RAGE(MP2RAGEimg,MP2RAGE,invEFF);

           FitResult.T1 = T1map.img;
           FitResult.R1 = R1map.img;
       end


    end
    
end