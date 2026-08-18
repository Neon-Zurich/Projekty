simOut= sim("rozdzielacz_test.slx");
kat_wartosc = kat.Data;
przeplyw_wartosc = przeplyw_zbiornik.Data;

plot(kat_wartosc, przeplyw_wartosc);
grid on;
xlabel("stopien otwarcia rozdzielacza [stopnie]");
ylabel("doplyw do/odplyw ze zbiornika [m3/h]");
title("charakterystyka statyczna rozdzielacza - doplyw/odplyw w funkcji kata otwarcia");

% wsp = [a, b] 
F = @(wsp, x) wsp(1) * tan(wsp(2) * (x - 90));

% b powinno być bliskie pi/180 (ok. 0.017), żeby tangens nie uciekł w nieskończoność
wsp0 = [10, 0.015]; 

% Wywołanie nieliniowej MNK
wsp_opt = lsqcurvefit(F, wsp0, kat_wartosc, przeplyw_wartosc);

a = wsp_opt(1);
b = wsp_opt(2);

fprintf('Wyznaczone parametry:\n a = %f\n b = %f\n', a, b);
y_model = F(wsp_opt, kat_wartosc);

figure;
plot(kat_wartosc, przeplyw_wartosc, 'o', kat_wartosc, y_model, '-r');
legend('Dane pomiarowe', 'Dopasowany Tangens');
grid on;
xlabel("stopien otwarcia rozdzielacza [stopnie]");
ylabel("doplyw do/odplyw ze zbiornika [m3/h]");
title("Dopasowanie funkcji do pomiarów");

% Odwrócenie
kat_obliczony = 90 + (1/b) * atan(przeplyw_wartosc / a);

% Zabezpieczenie: Kąt sterujący rozdzielacza ma fizyczny zakres od 0 do 180 stopni
if kat_obliczony > 180
    kat_sterujacy = 180;
elseif kat_obliczony < 0
    kat_sterujacy = 0;
else
    kat_sterujacy = kat_obliczony;
end

figure;
plot(przeplyw_wartosc, kat_wartosc, 'o', przeplyw_wartosc, kat_sterujacy, '-r');
legend('Dane pomiarowe', 'Dopasowanie odwrotne');
grid on;
ylabel("stopien otwarcia rozdzielacza [stopnie]");
xlabel("doplyw do/odplyw ze zbiornika [m3/h]");
title("Dopasowanie funkcji do pomiarów (invers)");