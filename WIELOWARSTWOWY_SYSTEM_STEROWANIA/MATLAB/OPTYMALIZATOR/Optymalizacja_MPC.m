% OPC UA connect/disconnect, read/write

uaClient = opcua("192.168.1.128",4840); 
connect(uaClient); 
V0 = findNodeByName(uaClient.Namespace,'V0','-once'); 
Godzina_symulacji = findNodeByName(uaClient.Namespace,'Godzina_symulacji','-once'); 
z0 = findNodeByName(uaClient.Namespace,'z0','-once');
z1 = findNodeByName(uaClient.Namespace,'z1','-once');
z2 = findNodeByName(uaClient.Namespace,'z2','-once');
z3 = findNodeByName(uaClient.Namespace,'z3','-once');
z4 = findNodeByName(uaClient.Namespace,'z4','-once');
z5 = findNodeByName(uaClient.Namespace,'z5','-once');
z6 = findNodeByName(uaClient.Namespace,'z6','-once');
z7 = findNodeByName(uaClient.Namespace,'z7','-once');
z8 = findNodeByName(uaClient.Namespace,'z8','-once');
z9 = findNodeByName(uaClient.Namespace,'z9','-once');
z10 = findNodeByName(uaClient.Namespace,'z10','-once');
z11 = findNodeByName(uaClient.Namespace,'z11','-once');
z12 = findNodeByName(uaClient.Namespace,'z12','-once');
z13 = findNodeByName(uaClient.Namespace,'z13','-once');
z14 = findNodeByName(uaClient.Namespace,'z14','-once');
z15 = findNodeByName(uaClient.Namespace,'z15','-once');
z16 = findNodeByName(uaClient.Namespace,'z16','-once');
z17 = findNodeByName(uaClient.Namespace,'z17','-once');
z18 = findNodeByName(uaClient.Namespace,'z18','-once');
z19 = findNodeByName(uaClient.Namespace,'z19','-once');
z20 = findNodeByName(uaClient.Namespace,'z20','-once');
z21 = findNodeByName(uaClient.Namespace,'z21','-once');
z22 = findNodeByName(uaClient.Namespace,'z22','-once');
z23 = findNodeByName(uaClient.Namespace,'z23','-once');

POMPA_ZAD = findNodeByName(uaClient.Namespace,'pompa_MPC','-once');
KAT_ZADANY = findNodeByName(uaClient.Namespace,'rozdzielacz_MPC','-once');
 
godzina_poprzednia = -1;

% Zakres optymalizacji w godzinach
Hp = 24;

% Wagi, u - koszt, q - uchyb
w_u = 0.01;
w_q = 120;

% Zbiornik, maksymalna różnica między optymalizacjami oraz wartość początkowa i ograniczenia
% V0 = 150;
eps_V0_zadane = 50;
V_lim = [50, 500];

% u_lim - macierz ograniczeń pompy i rozdzielacza [Pmin, Pmax, dp; Zmin,
% Zmax, dZ] (macierz 2x3)
u_lim = [0, 100, 20; -100, 100, 30];

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

profil_koszt = Cena_C22a;

% figure;
% plot(1:24, q);
% title("Realizacja zapotrzebowania z użyciem optymalizatora, w_u = " + w_u + ", w_q = " + w_q);
% hold on;
% plot(1:24, profil_poboru);
% grid on;
% hold off;
% xlabel("Czas [h]");
% ylabel("Przepływ [m^3/h]");
% legend("Rzeczywisty", "Żądany");


while true


    pause(0.1);
     V0_value = readValue(uaClient,V0);
    Godzina_symulacji_value = readValue(uaClient,Godzina_symulacji);

% Dynamiczne zawężenie eps_V0, aby "czarna skrzynka" nie wyrzuciła błędu
% Sprawdzamy ile miejsca zostało do Vmin (50) i Vmax (500)
    zapas_dol = V0_value - V_lim(1); % Odległość od 50
    zapas_gora = V_lim(2) - V0_value; % Odległość od 500

% Wybieramy najmniejszą dozwoloną wartość (żeby nie przekroczyć 50 z zadania, ale zadowolić if'y w funkcji)
    eps_V0 = double(min([eps_V0_zadane, zapas_dol, zapas_gora]));


    if  double(Godzina_symulacji_value) ~= double(godzina_poprzednia)
    z0_value = readValue(uaClient,z0);
    z1_value = readValue(uaClient,z1);
    z2_value = readValue(uaClient,z2);
    z3_value = readValue(uaClient,z3);
    z4_value = readValue(uaClient,z4);
    z5_value = readValue(uaClient,z5);
    z6_value = readValue(uaClient,z6);
    z7_value = readValue(uaClient,z7);
    z8_value = readValue(uaClient,z8);
    z9_value = readValue(uaClient,z9);
    z10_value = readValue(uaClient,z10);
    z11_value = readValue(uaClient,z11);
    z12_value = readValue(uaClient,z12);
    z13_value = readValue(uaClient,z13);
    z14_value = readValue(uaClient,z14);
    z15_value = readValue(uaClient,z15);
    z16_value = readValue(uaClient,z16);
    z17_value = readValue(uaClient,z17);
    z18_value = readValue(uaClient,z18);
    z19_value = readValue(uaClient,z19);
    z20_value = readValue(uaClient,z20);
    z21_value = readValue(uaClient,z21);
    z22_value = readValue(uaClient,z22);
    z23_value = readValue(uaClient,z23);
    

   % Zapotrzebowanie sieci
    profil_pobierania = [z0_value, z1_value, z2_value, z3_value, z4_value, z5_value, z6_value, z7_value, z8_value, z9_value, z10_value, z11_value, z12_value, z13_value, z14_value, z15_value, z16_value, z17_value, z18_value, z19_value, z20_value, z21_value, z22_value, z23_value];
    profil_pobie = profil_pobierania(1:Godzina_symulacji_value);
    profil_rania = profil_pobierania(Godzina_symulacji_value+1:24);
    profil_poboru = [profil_rania,profil_pobie];

    profil_ko = profil_koszt(1:Godzina_symulacji_value);
    profil_sztow = profil_koszt(Godzina_symulacji_value+1:24);
    profil_koszt = [profil_sztow,profil_ko];
    disp(profil_koszt);

    [U traj_zbiornik koszt q bledy] = MPC_SW19(Hp,w_u,w_q,double(V0_value),eps_V0,V_lim,u_lim,profil_koszt,double(profil_poboru));

    sterowanie_pompa = U(:,1);
    sterowanie_rozdzielacz = U(:,2);

    kat_obliczony = 90 + (1/0.015260) * atan(sterowanie_rozdzielacz / 20);

    if kat_obliczony > 180
        kat_sterujacy = 180;
    elseif kat_obliczony < 0
        kat_sterujacy = 0;
    else
        kat_sterujacy = kat_obliczony;
    end

    writeValue(uaClient,POMPA_ZAD, sterowanie_pompa(1));
    writeValue(uaClient,KAT_ZADANY, kat_sterujacy(1));
   
    godzina_poprzednia = Godzina_symulacji_value;
    end

end

disconnect(uaClient); 

