classdef ResMirrorSim < handle
    %LINECLOCKSIM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        cyclePeriod;
        aoOutputRate;
        phase = 0.05;
    end
    
    properties (Hidden)
        hTaskGalvo;
        hTaskGalvoSS;
        hTaskSync;
        hListenerRes;
        
        nSamps;
        nFwd;
        nBkwd;
    end
    
    properties (Hidden, SetAccess = private)
        hSI;
        hScan;
    end
    
    methods
        function obj = ResMirrorSim(hSI,scanner,dev)
            obj.hSI = hSI;
            obj.hScan = obj.hSI.hScanner(scanner);
            assert(isa(obj.hScan,'scanimage.components.scan2d.ResScan'));
            
            % galvo waveform task
            obj.hTaskGalvo = most.util.safeCreateTask('ResMirrorSimCtl');
            obj.hTaskGalvo.createAOVoltageChan(dev,0,'X Galvo Control',-10,10);
            obj.aoOutputRate = obj.hTaskGalvo.get('sampClkMaxRate');
            obj.hTaskGalvo.cfgDigEdgeStartTrig('Ctr0InternalOutput', 'DAQmx_Val_Rising');
            obj.hTaskGalvo.set('startTrigRetriggerable',true);
            obj.hTaskGalvo.control('DAQmx_Val_Task_Unreserve');
            
            % galvo single sample task
            obj.hTaskGalvoSS = most.util.safeCreateTask('ResMirrorSimCtlSS');
            obj.hTaskGalvoSS.createAOVoltageChan(dev,0,'X Galvo Control',-10,10);
            obj.hTaskGalvoSS.writeAnalogData(0);
            
            % period clock task
            obj.hTaskSync = most.util.safeCreateTask('ResMirrorSimSync');
            obj.hTaskSync.createCOPulseChanTime(dev, 0, '', 0.001, 0.001);
            obj.hTaskSync.cfgImplicitTiming('DAQmx_Val_ContSamps');
            obj.hScan.hTrig.periodClockIn = ['/' dev '/Ctr0InternalOutput'];
            obj.cyclePeriod = 1/obj.hScan.mdfData.nominalResScanFreq;
            
            % res amplitude listener
            obj.hListenerRes = addlistener(obj.hScan,'resonantScannerOutputVoltsUpdated',@(varargin)obj.resonantScannerOutputVoltsUpdated());
            obj.hScan.disableResonantZoomOutput = true;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTaskGalvo);
            most.idioms.safeDeleteObj(obj.hTaskSync);
            most.idioms.safeDeleteObj(obj.hListenerRes);
            
            try
                obj.hTaskGalvoSS.writeAnalogData(0);
            catch
            end
            most.idioms.safeDeleteObj(obj.hTaskGalvoSS);
        end
        
        function resonantScannerOutputVoltsUpdated(obj)
            v = obj.hScan.resonantScannerLastWrittenValue;
            
            if v
                %calc ao buffer
                amp = 10 * v / 5;
                ao = [linspace(amp,-amp,obj.nFwd)'; linspace(-amp,amp,obj.nBkwd)'];
                ao = circshift(ao,-floor(length(ao)*obj.phase));
                ao = min(10,max(-10,ao));
                %improve waveform?
                
                obj.writeAnalogData(obj.hTaskGalvo,ao);
                
                if obj.hTaskGalvo.isTaskDone
                    obj.hTaskGalvo.start();
                    obj.hTaskSync.start();
                end
            else
                abort(obj.hTaskGalvo);
                obj.hTaskGalvo.control('DAQmx_Val_Task_Unreserve');
                obj.hTaskGalvoSS.writeAnalogData(0);
                abort(obj.hTaskSync);
            end
        end
        
        function writeAnalogData(~,hTask,ao)
            done = false;
            hTask.writeAnalogDataAsync(ao,[],[],[],@doneCB);
            
            t = tic;
            while ~done
                pause(0.001);
                assert(toc(t) < 5, 'Timed out writing data');
            end
            
            function doneCB(src,evt)
                if evt.status ~= 0 && evt.status ~= 200015 && obj.hScan.active
                    fprintf(2,'Error updating x galvo buffer: %s\n%s\n',evt.errorString,evt.extendedErrorInfo);
                end
                done = true;
            end
        end
    end
    
    %% Prop Access
    methods    
        function set.phase(obj,v)
            obj.phase = v;
            obj.resonantScannerOutputVoltsUpdated();
        end
        
        function set.cyclePeriod(obj, v)
            assert(~obj.hSI.active, 'Cannot change cycle period during an acquisition.');
            
            obj.cyclePeriod = v;
            set(obj.hTaskSync.channels, 'pulseHighTime', v/2);
            set(obj.hTaskSync.channels, 'pulseLowTime', v/2);
            
            obj.nSamps = floor(obj.cyclePeriod * obj.aoOutputRate) - 1;
            obj.nFwd = floor(obj.nSamps/2);
            obj.nBkwd = obj.nSamps - obj.nFwd;
            
            obj.hTaskGalvo.cfgSampClkTiming(obj.aoOutputRate, 'DAQmx_Val_FiniteSamps', obj.nSamps);
            obj.hTaskGalvo.cfgOutputBuffer(obj.nSamps);
        end
    end
end



%--------------------------------------------------------------------------%
% ResMirrorSim.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
