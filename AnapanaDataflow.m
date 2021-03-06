%%Obtencion de los datos en formato edf de lecturas realizadas por el EPOC
% [cabeceraEO, datosEO]= edfread('LeoTest5EO3min.edf');
% [cabeceraEC, datosEC] = edfread('LeoTest5EC3min.edf');

%%Extraccion de poder espectral de cada electrodo del EPOC para las
%lecturas realizadas
EEGData = datosEC(3:16,:);

%%Transformacion - Limpieza
[electrodos,lecturas]=size(EEGData);
for e = 1:electrodos;
 for l = 1:lecturas;
%    disp(e)
%    disp(l)
%    disp(EEGData(e,l))
   if EEGData(e,l) < 0 %Normaliza valores negativos, es temporal mientras se establece preprocesamiento
      EEGData(e,l) = EEGData(e,l) * -1;
   end
   if EEGData(e,l) > 1000 %Aplica un filtro de paso alto, descartando los valores por encima de 1000 uV, mediante la asignacion de un valor significativamente bajo bajo
      EEGData(e,l) = EEGData(e,l) * .000001; 
   end
 end
end
EEGDataPrep = EEGData

%%inteligencia Computacional
%Parte 1: Clasificacion de neurose�ales con KNN, construccion del target
%de la ANN, basado en distancia euclideana
%Parte 1.1: Clasificacion KNN de cada electrodoXlectura con base a los
%valores espectrales del DMN
[electrodos,lecturas]=size(EEGDataPrep);
y = [354.9 14.7 54.9 23.6 12.9]; %Datos de entrenamiento, Valores espectrales promedio uV de las Ondas Delta, Theta, Alfa1, Alfa2 y Beta1 en el DMN
k = 5; %Definicion del valor del parametro del K-cercano, se definio arbitrariamente en 5 
for e = 1:electrodos;
 for l = 1:lecturas;
%    disp(e)
%    disp(l)
%    disp(EEGDataPrep(e,l))
   if EEGDataPrep(e,l) > 1 %Valida los valores que superan el umbral de los 1000uv queden por fuera
       dmn=1;%Reinicializa la pocision del arreglo a 1 para recorrer el vector de magnitudes de ref. en uV de DMN de nuevo
       disespectraldmn = zeros; %Reinicializa los valores del arreglo en 0 para recorrer el vector de magnitudes de ref. en uV de DMN de nuevo
       for dmn = 1:length(y)%Recorre las pocisiones del vector de magnitudes de ref.
         disespectraldmn(dmn) = sqrt((y(dmn) - EEGDataPrep(e,l))^2);%Calculo de la distancia euclideana de cada lecturaxelectrodo respecto a los targets espectrales del DMN       
         if min(disespectraldmn) < k %Si el valor de la menor distancia a alguno de los parametros espectrales, es menor que el parametro k ***implementacion knn***
            EEGDataCla(e,l) = 1; %Esta lectura, para este electrodo, se clasifica como presencia del DMN 1
         else
            EEGDataCla(e,l) = 0; %Esta lectura, para este electrodo, queda fuera del K, se clasifica como ausencia del DMN 0
         end
       end              
   end
 end
end
%Parte 1.2:Ponderacion del DMN para cada uno de los electrodos, basados en el clasificador KNN EEGDataCla,
%para cada lectura se a�ade un parametro ajustable de tolerancia (tol) que controla el numero de electrodos
%en DMN positivo (-->1) en EEGDataCla, que se se aceptan con (1), conformaran el target si hay
%presenecia o no de DMN para la n-lectura de manera mas precisa a partir de
%la presencia de los patrones espectrales en las lecturas de los electrodos
%para una epoca especifica.
[electrodos,lecturas]=size(EEGDataCla);%Se instancias los datos para el recorrido de la matriz clasifcada
tol = 1;%Valor de tolerancia, constante. Alerta! Si el parametro es muy bajo puede haber alta tasa de falsos positivos, pues con 
        %solo existir presencia de un rango espectral, la lectura completa
        %se pasa como estado DMN
sumdmnsegmento = sum(EEGDataCla);%Suma cada columna con la presencia espectral por lectura/electrodo del DMN. 1:TRUE 0:FALSE
for s=1:length(sumdmnsegmento)%Recorre la suma por columnas/lecturas
 if sumdmnsegmento(s) >= tol%Evalua la presencia de lecturas coincidentes con los rangos espectrales, con base a la tolerancia tol
   dmntarget(1,s) = 1; %Asigna 1 si la cantidad de lecturas/electrodo con presencia espectral del DMN, es mayor que la tolerancia
 else
   dmntarget(1,s) = 0; %Asigna 0 en caso contrario 
 end
end    

%%inteligencia Computacional
%Parte 2: Clasificacion a partir del target otorgado en la parte 1 con 
% KNN, aprendizaje supervisado con ANN
% Solve a Pattern Recognition Problem with a Neural Network
% Script generated by Neural Pattern Recognition app
% Created 06-May-2017 12:31:53
%
% This script assumes these variables are defined:
%    
%   EEGData - input data. EPOC RAW DATA USING EC MEDITATION APROX.
%   MINDFULNESS THECNIQUE, NO EXPERTICE, DURING 5 MINUTES.  
%   dmntarget - target data. Target , is the desired output for the given input, X.
%   Train the network with known input (X) and target (T).
%   The output of the resulting design, given the input, is output , Y.
%   The error is e = T-Y. Of course the most common ultimate goal of training is to minimize the mean-squared-error. 
%   The dmntarget is built on top of previous knn clasifier, has a matriz
%   of 1 row by n-columns-lectures KNN generated
x = EEGData;
t = dmntarget;

% Choose a Training Function
% For a list of all training functions type: help nntrain
% 'trainlm' is usually fastest.

% 'trainbr' takes longer but may be better for challenging problems.
% 'trainscg' uses less memory. Suitable in low memory situations.
trainFcn = 'trainscg';  % Scaled conjugate gradient backpropagation.

% Create a Pattern Recognition Network
hiddenLayerSize = 10;
net = patternnet(hiddenLayerSize);

% Setup Division of Data for Training, Validation, Testing
net.divideParam.trainRatio = 70/100;
net.divideParam.valRatio = 15/100;
net.divideParam.testRatio = 15/100;

% Train the Network
[net,tr] = train(net,x,t);

% Test the Network
y = net(x);
e = gsubtract(t,y);
performance = perform(net,t,y)
tind = vec2ind(t);
yind = vec2ind(y);
percentErrors = sum(tind ~= yind)/numel(tind);

% View the Network
view(net)

% Plots
% Uncomment these lines to enable various plots.
%figure, plotperform(tr)
%figure, plottrainstate(tr)
%figure, ploterrhist(e)
%figure, plotconfusion(t,y)
%figure, plotroc(t,y)

%%inteligencia Computacional
%Parte 3: Integracion de un RBC que cuente con reglas para la guianza de la
%meditacion autoasistida







