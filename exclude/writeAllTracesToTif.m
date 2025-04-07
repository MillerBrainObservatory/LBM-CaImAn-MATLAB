%%

load('neuron_coordinates_and_traces.mat')

Tt = T_all./(max(T_all,[],2)*ones(1,T));
Tt = movmean(Tt,5,2);
Tt(Tt<0) = 0;
Tt = Tt.*255;
Tt = uint8(Tt);
map = parula(256);
Ttc = ind2rgb(Tt,map);
Ttc = uint8(Ttc.*255);

R = max([Rv Rs],[],2);
[R,inds] = sort(R,'descend');

Ttc = Ttc(inds,:,:);

figure; imagesc(Ttc(1:2000,:,:));

buffer = 255.*ones(K,150,3,'uint8');

Ttt = cat(2,Ttc,buffer);

TTr = [];
Ku = K/10;

for ijk = 1:10

    ind1 = (ijk-1)*Ku + 1;
    ind2 = ijk*Ku;
    
    TTr = cat(2,TTr,Ttt(ind1:ind2,:,:));
end
