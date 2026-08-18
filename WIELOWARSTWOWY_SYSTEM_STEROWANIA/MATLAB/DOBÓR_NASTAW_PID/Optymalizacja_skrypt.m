%% Czyszczenie środowiska
clear;
clc;

%% ========================================================================
%% USTAWIENIA I WYBÓR KRYTERIUM
% Wybierz kryterium wpisując odpowiedni tekst:
% 'wagi_bez_przeregulowania' - Najniższy wskaźnik J = w1*RiseTime + w2*ISE, Overshoot = 0
% 'wagi_pelne_ograniczenie'  - Najniższy wskaźnik J = w1*RiseTime + w2*ISE, Overshoot = 0, delta(u) <= 5, SettlingTime < 40s
kryterium = 'wagi_bez_przeregulowania'; 

% Wagi kryterium jakości (J = w1 * RiseTime + w2 * ISE)
w1 = 200;  % Waga dla czasu narastania
w2 = 1;  % Waga dla sumy kwadratu uchybu (ISE)

% Definicja przestrzeni poszukiwań parametrów PID
kp_values = 1:0.25:10;  
Ti_values = 1:0.25:10;  
Td_values = 0;  

% Maksymalna dozwolona zmiana sygnału sterującego (dla drugiego kryterium)
max_delta_u = 5.0; 

% Nazwa modelu Simulinka
model_name = 'Sym_opt'; 
%% ========================================================================

% Ładowanie modelu do pamięci
load_system(model_name);

% Inicjalizacja zmiennych dla najlepszego wyniku (Szukamy MINIMUM funkcji J)
best_J = Inf; 
best_rise_time = NaN;
best_settling_time = NaN;
best_ise_val = NaN;
best_kp = NaN; best_Ti = NaN; best_Td = NaN;
best_sim_yout = []; best_sim_uout = [];

fprintf('Rozpoczynam pętlę optymalizacyjną dla kryterium: "%s"...\n', kryterium);

%% Główna pętla przeszukująca
for kp = kp_values
    for Ti = Ti_values
        for Td = Td_values
            
            % Wrzucenie nastaw do Workspace
            assignin('base', 'Kp', kp);
            assignin('base', 'Ti', Ti);
            assignin('base', 'Td', Td);
            
            try
                % Uruchomienie symulacji
                simOut = sim(model_name, 'SrcWorkspace', 'current');
                
                % Ekstrakcja danych wyjściowych i sterowania
                y_signal = simOut.y.Data;
                t_signal = simOut.y.Time;
                u_signal = simOut.u.Data;
                
                % Pobranie końcowej wartości ISE z symulacji (ostatnia próbka)
                ise_value = simOut.ise.Data(end);
                
                % Analiza wskaźników jakości z wymuszeniem progu 2% dla czasu ustalania
                info = stepinfo(y_signal, t_signal, 'SettlingTimeThreshold', 0.02);
                
                % Inicjalizacja flagi dopuszczalności rozwiązania
                is_valid = false;
                
                % Sprawdzenie warunków logicznych i ograniczeń
                if strcmp(kryterium, 'wagi_bez_przeregulowania')
                    % Przypadek 1: Brak przeregulowania
                    if info.Overshoot == 0 && ~isnan(info.RiseTime) && ~isnan(ise_value)
                        is_valid = true;
                    end
                    
                elseif strcmp(kryterium, 'wagi_pelne_ograniczenie')
                    % Przypadek 2: Brak przeregulowania + Ograniczenie sterowania + Czas ustalania < 40s
                    delta_u = max(abs(diff(u_signal))); 
                    
                    if info.Overshoot == 0 && ...
                       delta_u <= max_delta_u && ...
                       ~isnan(info.SettlingTime) && info.SettlingTime < 40 && ...
                       ~isnan(info.RiseTime) && ...
                       ~isnan(ise_value)
                   
                        is_valid = true;
                    end
                end
                
                % Jeśli parametry są dopuszczalne, obliczamy funkcję celu J
                if is_valid
                    % Obliczenie wypadkowego wskaźnika jakości
                    current_J = (w1 * info.RiseTime) + (w2 * ise_value);
                    
                    % Szukamy kombinacji, która MINIMALIZUJE wartość J
                    if current_J < best_J
                        best_J = current_J;
                        best_rise_time = info.RiseTime;
                        best_settling_time = info.SettlingTime;
                        best_ise_val = ise_value;
                        best_kp = kp;
                        best_Ti = Ti;
                        best_Td = Td;
                        best_sim_yout = simOut.y;
                        if isprop(simOut, 'u') || isfield(simOut, 'u'), best_sim_uout = simOut.u; end
                    end
                end
                
            catch ME
                % Ignoruj błędy dla niestabilnych nastaw
                continue;
            end
            
        end
    end
end

%% Wyświetlenie wyników i generowanie wykresów
fprintf('\n================ ZAKOŃCZONO ================ \n');
if ~isnan(best_kp)
    fprintf('Najlepsze nastawy dla kryterium [%s]:\n', kryterium);
    fprintf('Kp = %.3f | Ti = %.3f | Td = %.3f\n', best_kp, best_Ti, best_Td);
    fprintf('Zminimalizowany wskaźnik jakości J = %.4f\n', best_J);
    fprintf(' -> Składowa czasu narastania (RiseTime): %.4f s\n', best_rise_time);
    fprintf(' -> Czas ustalania (SettlingTime 2%%): %.4f s\n', best_settling_time);
    fprintf(' -> Składowa uchybu (ISE): %.4f\n', best_ise_val);
    
    % Rysowanie wykresów
    figure('Name', 'Wyniki Optymalizacji PID z ISE', 'NumberTitle', 'off');
    
    % Wykres 1: Odpowiedź układu (Wyjście)
    subplot(2,1,1);
    plot(best_sim_yout.Time, best_sim_yout.Data, 'b', 'LineWidth', 2);
    grid on;
    title('Odpowiedź skokowa układu (Sygnał wyjściowy y)');
    xlabel('Czas [s]'); ylabel('y(t)');
    
    % Wykres 2: Sygnał sterujący
    if ~isempty(best_sim_uout)
        subplot(2,1,2);
        plot(best_sim_uout.Time, best_sim_uout.Data, 'r', 'LineWidth', 1.5);
        grid on;
        title(sprintf('Sygnał sterujący u (Max dozwolona zmiana: %.2f)', max_delta_u));
        xlabel('Czas [s]'); ylabel('u(t)');
    end
else
    warning('Nie znaleziono żadnych nastaw spełniających wybrane kryteria i ograniczenia!');
end