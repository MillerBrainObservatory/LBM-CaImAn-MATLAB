function [inputTable,outputTable] = displayArgs(name)
%%
arguments (Input)
	name	(1,1)	string
end

arguments (Output)
	inputTable		table
	outputTable		table
end
%%

F = matlab.internal.metafunction(name);
if isempty(F)
	if nargout==0
		disp(compose("'%s' not found.",name))
	else
		inputTable = table.empty;
		outputTable = table.empty;
	end
	return
end

%%
I = F.Signature.Inputs;

inputs = table;
inputs.Name = string({I.Name}).';
inputs.Kind = char(pad(string([I.Kind]).'+",")+" "+pad(string([I.Presence]).'));
inputs.Group = [I.NameGroup].';
[inputs.Class, inputs.Size, inputs.Validation, inputs.HasDefault, inputs.Default] = arrayfun(@getval, I(:));
inputs.Description = [I.Description].';

%%
O = F.Signature.Outputs;

outputs = table;
outputs.Name = string({O.Name}).';
[outputs.Class, outputs.Size, outputs.Validation] = arrayfun(@getval, O(:));
outputs.Description = [O.Description].';

%%
if nargout~=0
	inputTable = inputs;
	outputTable = outputs;
	return
end

%%

display_inputs = inputs;

for ii = 1:height(inputs)
	if inputs.HasDefault(ii)=='n'
		display_inputs.Default{ii} = "";
	elseif inputs.HasDefault(ii)=='y'
		display_inputs.Default{ii} = formattedDisplayText(inputs.Default{ii});
	else
		display_inputs.Default{ii} = "{Dependent}";
	end
end
display_inputs.Default = cat(1,display_inputs.Default{:});
display_inputs.HasDefault = [];

display_inputs.Size = cellfun(@sizelabel, display_inputs.Size);
display_inputs.Validation = cellfun(@(X) strjoin(X,", "), display_inputs.Validation);
for c = string(display_inputs.Properties.VariableNames(:)).'
	if isstring(display_inputs.(c))
		if isequal(display_inputs.(c), "")
			display_inputs.(c) = char.empty(height(display_inputs),0);
		else
			display_inputs.(c) = char(display_inputs.(c));
		end
		% display_inputs.(c) = char(display_inputs.(c));
	end
end




display_outputs = outputs;

display_outputs.Size = cellfun(@sizelabel, display_outputs.Size);
display_outputs.Validation = cellfun(@(X) strjoin(X,", "), display_outputs.Validation);
for c = string(display_outputs.Properties.VariableNames(:)).'
	if isstring(display_outputs.(c))
		if isequal(display_outputs.(c), "")
			display_outputs.(c) = char.empty(height(display_outputs),0);
		else
			display_outputs.(c) = char(display_outputs.(c));
		end
	end
end


%%

input_text = formattedDisplayText(display_inputs);
% input_text = "INPUTS:"+newline+input_text;

input_text = regexprep(input_text,"(?m)^(.)","  $1");
input_text = regexprep(input_text,"^   ","IN:");
input_text = regexprep(input_text,"(?<=^.*_{5}.*[\r\n])  (?=[^\r\n]*\w)","-> ");
% input_text = "-- INPUTS:"+newline+input_text;

output_text = formattedDisplayText(display_outputs);
output_text = regexprep(output_text,"(?m)^(.)","  $1");
output_text = regexprep(output_text,"^    ","OUT:");
output_text = regexprep(output_text,"(?<=^.*_{5}.*[\r\n])  (?=[^\r\n]*\w)","<- ");
% output_text = "-- OUTPUTS:"+newline+output_text;
% output_text = regexprep("OUTPUTS:"+newline+output_text,"(?m)^(.)","<- $1");

display_text = input_text+newline+output_text;
% display_text = compose("INPUTS:\n%s\nOUTPUTS:\n%s",input_text,output_text);
% display_text = regexprep(display_text,"(?m)^(.)","{ $1");
disp(display_text)

%%
end
%%
function [argClass,argSize,valfun,hasdef,defval] = getval(arg)
	arguments (Input)
		arg
	end
	arguments (Output)
		argClass	(1,1)	string
		argSize		(1,1)	cell
		valfun		(1,1)	cell
		hasdef		(1,1)	char
		defval		(1,1)	cell
	end

	argClass = "";
	argSize = {double.empty(1,0)};
	valfun = {string.empty(1,0)};

	if ~isempty(arg.DefaultValue)
		if arg.DefaultValue.IsConstant
			hasdef = 'y';
			defval = {arg.DefaultValue.Value};
		else
			hasdef = 'v';
			defval = {{}};
		end
	else
		hasdef = 'n';
		defval = {{}};
	end

	V = arg.Validation;
	if isempty(V), return, end

	if ~isempty(V.Class)
		argClass = V.Class.Name;
	end

	if ~isempty(V.Size)
		sz = nan(1,numel(V.Size));
		for ii = 1:numel(V.Size)
			switch class(V.Size(ii))
				case "matlab.internal.metadata.UnrestrictedDimension"
					sz(ii) = inf;
				case "matlab.internal.metadata.FixedDimension"
					sz(ii) = V.Size(ii).Length;
				otherwise
					return
			end
		end
		argSize = {sz};
	end

	if ~isempty(V.Functions)
		if isMATLABReleaseOlderThan('R2024a')
			valfun = [V.Functions.Name];
		else
			valfun = [V.Functions.StringValue];
		end
		[~,idx] = sort(strlength(valfun));
		valfun = {valfun(idx)};
	end
end

%%
function argSizeStr = sizelabel(sz)
	arguments (Input)
		sz
	end
	arguments (Output)
		argSizeStr	(1,1)	string
	end

	if isempty(sz)
		argSizeStr = "";
		return
	end
	% N = numel(sz);
	% qfun = @(X) strrep(X,"Inf","[?]");
	% matfun = @(X) qfun(compose("%i by %i 2D array",X));

	% if isequal(sz, [1 1]),		argSizeStr = "scalar";
	% elseif isequal(sz,[inf 1]),	argSizeStr = "column vector";
	% elseif isequal(sz,[1 inf]),	argSizeStr = "row vector";
	% % elseif all(sz==Inf),		argSizeStr = compose("%i-D array",numel(sz));
	% % elseif N==2,				argSizeStr = matfun(sz);
	% else
		argSizeStr = "("+strjoin(strrep(string(sz),"Inf",":"),",")+")";
	% end
end
