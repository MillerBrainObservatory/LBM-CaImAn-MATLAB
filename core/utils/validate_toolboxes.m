function [output] = validate_toolboxes()
% Report missing MATLAB toolboxes that are required to execute this pipeline.

v = ver;
installed = {v.Name};
required = {
	'Parallel Computing Toolbox', ...
	'Statistics and Machine Learning Toolbox', ...
	'Image Processing Toolbox', ...
	'Signal Processing Toolbox' ...
	};

missing = {};
for i = 1:length(required)
	if ~any(strcmp(installed, required{i}))
		missing{end+1} = required{i};
	end
end

if isempty(missing)
	output = 1;
	fprintf('All required toolboxes are installed.\n');
else
	output = sprintf('%s is not installed. ', missing{:});
	output = [output 'Please install these toolboxes and try again.'];
	fprintf('%s\n', output);
end
end
