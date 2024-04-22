function []=remindme_atom(time,msg)
%REMINDME(time,msg)  Will issue a remider (msg) at the specified time.
% Default msg is: 'This is your reminder.'
%
% Example:   >>remindme('1:20','There is more to life than Matlab.')
% Will issue a message to the user at 1:20.
% The maximum usable time is 12 hours, but who works longer anyway?

if nargin < 2
    msg = '  This is your reminder.';
end

% Get the current time in hours (12hour format).
crnt = mod(now+getCurrentTimeDelta,0.5)*24;


if length(time)==4   % hrs is the number of hours till remind.
    hrs = str2double(time(1))+str2double(time(3:4))/60;  
elseif length(time)==5
    hrs = str2double(time(1:2))+str2double(time(4:5))/60;
else
    error('Time must be in the format hh:mm or h:mm only.');
end

nmhrs = max([mod(12,hrs-crnt) mod(hrs-crnt,12)]);  % Hours to delay. 

tmr = timer('Name','Reminder',...
      'Period',10*60,...  % 10 minute snooze time.
      'StartDelay',round(nmhrs*3600),... % alarm time in seconds.
      'TasksToExecute',3,...  % number of snoozes allowed.
      'ExecutionMode','fixedSpacing',...
      'TimerFcn',{@reminder, {time,msg}},...   % Function def. below.
      'StopFcn',@deleter);   % Function def. below.       

start(tmr);
end


function reminder(obj, edata, msg) %#ok
% Callback for timerfcn.

a = load ( 'train' );   % Here make a mix of sounds to go with the reminder.
yt = a.y;
a = load ( 'gong' );
yg = a.y;
a = load ( 'laughter' );
y = [yt;yg;a.y];
sound(y,a.Fs);

if get(obj, 'TasksExecuted') == 3  % Completed three snoozes
  btn = questdlg(msg,...   % question
        'Reminder: Final',...  % title
        'O.k. (Stop)',...   % button1
        'O.k. (Stop)');   % default
else
  btn = questdlg(msg,...   % question                                        
        sprintf('Reminder: #%d',get(obj,'TasksExecuted')),... % title        
        'O.k. (Stop)',...   % button1                                                         
        sprintf('Snooze (%0.2g min)',get(obj,'Period')/60),...   % button2                 
        'O.k. (Stop)');   % default                                                      
end

clear playsnd;

if isequal(btn,'O.k. (Stop)')
   set(obj, 'TasksToExecute', get(obj, 'TasksExecuted')); 
end
end

function deleter(obj, edata) %#ok
% Callback for stopfcn.
wait(obj);
delete(obj);
end

function [ timeDelta ] = getCurrentTimeDelta( timeZone )
%GETCURRENTTIMEDELTA Gets the offset in time of the system clock.
%Time format is compatible with now. To get exact time, add the
%return value to the current system time. As an optional argument,
%supply the time-zone.


URL = 'http://tycho.usno.navy.mil/cgi-bin/timer.pl';
atomTime = datenum(regexp(urlread(URL), ...
   '<BR>(.*)\sUTC','tokens','once'),'mmm. dd, HH:MM:SS');
sysTime = now;

if ( nargin == 0 ) 
    % Assume time diff is less than 1 hour
    timeDelta = atomTime - sysTime;
    timeDeltaInHours = timeDelta*24;    
    timeDelta = (timeDeltaInHours - round(timeDeltaInHours))/24;    
else
    timeDelta = atomTime - sysTime + timeZone/24;
end

end


%--------------------------------------------------------------------------%
% remindme_atom.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
