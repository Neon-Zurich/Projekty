plik = 'C:\Users\student\Documents\s199050_s199232\SCADAzapisy\pomiary.txt';
opcje = detectImportOptions(plik, 'Delimiter', ';');

opcje.VariableNames = {'Czas_str', 'Poziom', 'Przeplyw'};
dane = readtable(plik, opcje);

try
    czas = datetime(dane.Czas_str, 'InputFormat', 'dd.MM.yyyy HH:mm:ss');
catch
    czas = 1:height(dane);
end

figure('Name', 'Dane wygenerowane z wykorzystaniem SCADA', 'NumberTitle', 'off');

subplot(2, 1, 1);
plot(czas, dane.Poziom);
title('Poziom w zbiorniku');
ylabel('Poziom [m]');
grid on;

subplot(2, 1, 2);
plot(czas, dane.Przeplyw);
title('Przepływ do sieci');
ylabel('Przepływ [m^3/h]');
xlabel('Czas');
grid on;