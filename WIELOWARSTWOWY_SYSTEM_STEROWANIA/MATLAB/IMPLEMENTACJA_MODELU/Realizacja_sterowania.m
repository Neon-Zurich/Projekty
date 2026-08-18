V0 = 150;
k = 0.9;
T = 60;

kp = 6;
Ti = 6;
Td = 0;

% 1 - 1 s = 1 minuta
% 2 - 1 s = 10 minut
% 3 - 1 s = 1 godzina
tryb = 1;
switch tryb
    case 1
        T_max = 24 * 60;
    case 2
        T_max = 24 * 6;
    case 3
        T_max = 24;
%     case 4
%         T_max = 24 * 60 * 60;
end
T_symulacji = inf;

zapotrzebowanie = [40, 30, 30, 40, 60, 80, 140, 180, 160, 110, 90, 80, 70, 80, 80, 110, 120, 110, 110, 90, 80, 70, 60, 50] * (24 / T_max);
% pompa_C21 = [76.25, 76.25, 76.25, 76.25, 76.25, 86.25, 100, 100, 100, 100, 86.25, 76.25, 86.25, 76.25, 86.25, 100, 100, 100, 100, 76.25, 76.25, 76.25, 76.25, 86.25] * (24 / T_max);
pompa_C22a = [100, 80, 90, 100, 95, 80, 100, 100, 60, 10, 0, 100, 100, 100, 100, 100, 100, 100, 55, 90, 80, 100, 100, 100];
% pompa_C22b = [100, 100, 100, 100, 95, 80, 40, 80, 60, 40, 45, 90, 90, 90, 90, 100, 100, 100, 100, 90, 80, 100, 100, 100] * (24 / T_max);
% pompa_C23 = [100, 100, 100, 100, 95, 80, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 10, 10, 30, 45, 100, 100, 100] * (24 / T_max);
pompa_zadana = pompa_C22a;
% 
u = pompa_zadana - zapotrzebowanie;
% Odwrócenie
kat_obliczony = 90 + (1/0.015260) * atan(u / 20);

% Zabezpieczenie: Kąt sterujący rozdzielacza ma fizyczny zakres od 0 do 180 stopni
if kat_obliczony > 180
    kat_sterujacy = 180;
elseif kat_obliczony < 0
    kat_sterujacy = 0;
else
    kat_sterujacy = kat_obliczony;
end

disp(kat_sterujacy);

%T_probkowania = 2 * T_max / (60 * 24);
T_probkowania = 0.1;
T_step = T_max / 24;

% Ceny: energia (2019 - marzec, marzec to zima) + opłata sieciowa + opłata jakościowa
% Całodobowa
C21 = 0.4030 + 0.1792 + 0.0125;
Cena_C21 = C21 * ones(1, 24);
% 2 Strefy szczytowa i nie
C22a_up = 0.4950 + 0.2115 + 0.0125;
C22a_down = 0.3660 + 0.1483 + 0.0125;
Cena_C22a = [C22a_down * ones(1,8), C22a_up * ones(1,3), C22a_down * ones(1,7), C22a_up * ones(1,3), C22a_down * ones(1,3)];
% 2 strefy dzień i noc
C22b_up = 0.4620 + 0.1807 + 0.0125;
C22b_down = 0.2840 + 0.0836 + 0.0125;
Cena_C22b = [C22b_down * ones(1,6), C22b_up * ones(1,15), C22b_down * ones(1,3)];
% 3 strefy na dzień (jeśli zużycie poniżej 200 MWh/rok to C23 staje się C21,
% jeśli C21 jest mniej korzystne)
C23_up_first = 0.5130 + 0.1920 + 0.0125;
C23_up_last = 0.5490 + 0.2757 + 0.0125;
C23_down = 0.3330 + 0.0700 + 0.0125;
Cena_C23 = [C23_down * ones(1,7), C23_up_first * ones(1,6), C23_down * ones(1,3), C23_up_last * ones(1,5), C23_down * ones(1,3)];

Cena_C21_sim = Cena_C21  * (24 / T_max);
Cena_C22a_sim = Cena_C22a  * (24 / T_max);
Cena_C22b_sim = Cena_C22b  * (24 / T_max);
Cena_C23_sim = Cena_C23  * (24 / T_max);

% simOut= sim("rozdzielacz_implementacja.slx");
% siec_zapotrzebowanie = siec.Data;
% zbiornik = zbiornik_obj.Data;
% zmiana_zbiornik = zbiornik_do_z.Data;
% pompa_wartosc = pompa.Data;
% kat_wartosc = kat.Data;
% % zapotrzebowanie_wartosc = zadane_zapotrzebowanie.Data;
% 
% koszty_C21 =  ((T_max / 24) * pompa_C21) .* Cena_C21;
% koszty_C22a = ((T_max / 24) * pompa_C22a) .* Cena_C22a;
% koszty_C22b = ((T_max / 24) * pompa_C22b) .* Cena_C22b;
% koszty_C23 = ((T_max / 24) * pompa_C23) .* Cena_C23;
% 
% error_val = error.Data;
% ISE_values = ISE.Data;
% przelanie_val = przelanie.Data;
% 
% t = 1 : 24;
% 
% figure;
% plot(kat.Time * (24/ T_max), kat_wartosc);
% title("Sterowanie kat rozdzielacza");
% xlabel("Czas [h]");
% ylabel("kat rozdzielacza [stopnie]");
% grid on;
% 
% figure;
% title("Przepływ z pompy");
% xlabel("Czas [h]");
% ylabel("Przepływ z pompy [m3/h]");
% grid on;
% hold on;
% plot(pompa.Time * (24/ T_max), pompa_wartosc);
% hold off;
% 
% figure;
% title("Przepływ do/z zbiornika");
% xlabel("Czas [h]");
% ylabel("Przepływ do/z zbiornika [m3/h]");
% grid on;
% hold on;
% plot(zbiornik_do_z.Time * (24/ T_max), zmiana_zbiornik);
% hold off;
% 
% % figure;
% % title("Spełnienie zapotrzebowania");
% % xlabel("Czas [h]");
% % ylabel("doplyw do sieci [m3/h]");
% % grid on;
% % hold on;
% % plot(siec.Time * (24/ T_max), siec_zapotrzebowanie);
% % plot(zadane_zapotrzebowanie.Time * (24/ T_max), zapotrzebowanie_wartosc);
% % hold off;
% % legend("Wyjście mierzone", "Wartości zadane");
% 
% figure;
% title("Poziom wypełnienia zbiornika");
% xlabel("Czas [h]");
% ylabel("stan zbiornika [m3]");
% grid on;
% hold on;
% plot(zbiornik_obj.Time * (24/ T_max), zbiornik);
% hold off;
% 
% figure;
% title("Zestawienie kosztów");
% xlabel("Czas [h]");
% ylabel("Koszt [zł]");
% grid on;
% hold on;
% plot(t, koszty_C21);
% plot(t, koszty_C22a);
% plot(t, koszty_C22b);
% plot(t, koszty_C23);
% hold off;
% legend("C21, łącznie = " + round(sum(koszty_C21), 2) + " zł", "C22a, łącznie = " + round(sum(koszty_C22a), 2) + " zł", "C22b, łącznie = " + round(sum(koszty_C22b), 2) + " zł", "C23, łącznie = " + round(sum(koszty_C23), 2) + " zł");
% 
% figure;
% subplot(2, 1, 1);
% plot(error.Time * (24/ T_max), error_val);
% grid on;
% title("Błąd dostarczania wody do sieci");
% ylabel("Błąd dostarczania wody");
% xlabel("Czas [h]");
% subplot(2, 1, 2);
% plot(ISE.Time, ISE_values);
% title("Błąd sumowany w kwadracie ISE");
% grid on;
% ylabel("ISE");
% xlabel("Czas [h]");