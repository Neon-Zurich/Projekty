% Projekt KSS sem.6 AiR WEiA PG rok akademicki 2018/2019 (c) AC, JT
% Skrypt wyznaczający optymalne sterowania pompą i rozdzielaczem
%
% [U traj_zbiornik koszt q bledy] = MPC_SW19(Hp,w_u,w_q,V0,eps_V0,V_lim,u_lim,profil_koszt,profil_poboru)
% ------ argumenty wejściowe ------- 
% Hp - horyzont predykcji (skalar)
% w_u - waga kosztów użyta w kryterium (skalar)
% w_q - waga błedów użyta w kryterium (skalar)
% V0 - objętość początkowa wody w zbiorniku (skalar)
% eps_V0 - pozwala określić w jakim przedziale ma być objętość wody na końcu horyzontu (V0-eps_V0, V0+eps_V0) (skalar)
% V_lim - macierz zawierająca ograniczenia na objętość wody w zbiorniku [Vmin, Vmax] (macierz 1x2)
% u_lim - macierz ograniczeń pompy i rozdzielacza [Pmin, Pmax, dp; Zmin,
% Zmax, dZ] (macierz 2x3)
% profil_koszt  - wektor zawierający koszt energii elektrycznej    (wektor 1xHp)
% profil_poboru - wektor zawierający zapotrzebowania sieci na wodę (wektor 1xHp)
% ------ wyniki optymalizacji -------
% U - sterowania pompą i rozdzielaczem (macierz Hpx2)
% traj_zbiornik - wartości objętości zbiornika (wektor Hp+1x1)
% koszt - koszt użycia pompy przy zadanej taryfie (skalar)
% q - przepływ do sieci (Hpx1)
% bledy - róznica pomiędzy zapotrzebowaniem i przepływem do sieci (Hpx1)


function [U traj_zbiornik koszt q bledy] = MPC_SW19(Hp,w_u,w_q,V0,eps_V0,V_lim,u_lim,profil_koszt,profil_poboru)
Vmin=V_lim(1,1); Vmax=V_lim(1,2);   % ograniczenia na stan wody w zbiorniku 
Pmin=u_lim(1,1); Pmax=u_lim(1,2);  dP=u_lim(1,3); % ograniczenia na wydajnosc pompy
Zmin=u_lim(2,1); Zmax=u_lim(2,2);  dZ=u_lim(2,3); % ograniczenia na przeplyw do zbiornika wymuszany przez rozdzelacz 
% dP, dZ maksymalna dopuszczalna zmiana pracy pompy pomiedzy godzinami 

%Poniewaz zwykle V0 przychodzi z OPC jako real single a quadprog dziala na real double 
% dokonuje jawnej konwersji na double
V0_double = double(V0);

%wykrycie bledow argumantow wejsciowych 
if (Hp <= 0) error('!!!!!!!! Horyzont predykcji musi być >0 !!!!!!!!'); end
if rem(Hp,1)>0 error('!!!!!!!! Horyzont predykcji musi być liczbą całkowitą >0 !!!!!!!!'); end
if size(profil_poboru,1)>1 error('!!!!!!!! Wektor poboru wody musi być rozmiaru [1xHp] !!!!!!!!'); end
if size(profil_koszt,1)>1  error('!!!!!!!! Wektor kosztów sterowania musi być rozmiaru [1xHp] !!!!!!!!'); end
if numel(profil_poboru)~=Hp error('!!!!!!!! Długość wektora poboru wody musi być = Hp !!!!!!!!'); end
if numel(profil_koszt)~=Hp error('!!!!!!!! Długość wektora kosztów sterowania musi być = Hp !!!!!!!!');end
if size(u_lim)~=[2 3] error('!!!!!!!! Macierz ograniczeń na sterowania musi być rozmiaru [2x3] !!!!!!!!'); end
if size(V_lim)~=[1 2] error('!!!!!!!! Macierz ograniczeń na zbiornik musi być rozmiaru [1x2] !!!!!!!!'); end
if w_u < 0 error('!!!!!!!! Waga kosztów wu musi być >=0   !!!!!!!!'); end
if w_q < 0 error('!!!!!!!! Waga bledow wq musi być >=0   !!!!!!!!'); end
if (Vmin<0) error('!!!!!!!! Wartość dolnego ograniczenia na zbiornik musi być >=0 !!!!!!!!'); end
if (Vmax<0) error('!!!!!!!! Wartość gornego ograniczenia na zbiornik musi być >=0 !!!!!!!!'); end
if (Vmin>Vmax) error('!!!!!!!! Wartość dolnego ograniczenia na zbiornik musi być < od górnego ograniczenia!!!!!!!!'); end
if ((V0>Vmax) || (V0<Vmin)) error('!!!!!!!! Warunek początkowy stanu lustra wody musi być w granicach [%0.1f - %0.1f]!!!!!!!!',V_lim(1),V_lim(2)); end
if (eps_V0<0) error('!!!!!!!! Parametr eps_V0 musi być >= 0 !!!!!!!!'); end
%if (V0_double+eps_V0>Vmax) error('!!!!!!!! parametr eps_V0 jest zle dobrany poniewaz V0+eps_V0>Vmax  !!!!!!!!'); end
%if (V0_double-eps_V0<Vmin) error('!!!!!!!! parametr eps_V0 jest zle dobrany poniewaz V0-eps_V0<Vmin  !!!!!!!!'); end
if (Pmin<0) error('!!!!!!!! Wydajność pompy musi być >= 0 !!!!!!!!'); end
if (Pmax<0) error('!!!!!!!! Wydajność pompy musi być >= 0 !!!!!!!!'); end
if (Pmin>Pmax) error('!!!!!!!! Wydajność max pompy musi być Pmax >= od Pmin !!!!!!!!'); end
if (dP > Pmax-Pmin) error('!!!!!!!! Dopuszczalna zmiana pracy pompy w jednej godzinie wieksza niz mozliwosci pompy !!!!!!!!'); end

if (Zmin>=0) error('!!!!!!!! Ograniczenie na rozdzielacz wyklucza przeplyw ze zbiornika; Zmin musi byc < 0 !!!!!!!!'); end
if (Zmax<=0) error('!!!!!!!! Ograniczenie na rozdzielacz wyklucza przeplyw do zbiornika; Zmax musi byc > 0 !!!!!!!!'); end
if (Zmin>Zmax) error('!!!!!!!! Ograniczenie na rozdzielacz musi być Zmax >= od Zmin !!!!!!!!'); end
if (dZ > abs(Zmax-Zmin)) error('!!!!!!!! Dopuszczalna zmiana pracy rozdzielacza w jednej godzinie wieksza niz mozliwosci rozdzielacza !!!!!!!!'); end

% MODEL OBIEKTU!  ograniczenia rownosciowe bilansowe P=Z+S; V(k+1)=V(k)+Z; B=S-zap  
Aeq=[];lb=[];ub=[];A=[];b=[]; % zerowanie macierzy ograniczen 

M1 =  diag(ones(1,Hp)); M1 = [M1 zeros(Hp,1)];
M2 =  -diag(ones(1,Hp)); M2 = [zeros(Hp,1) M2];
M = M1 + M2; 
Aeq = [     diag(ones(1,Hp)) -diag(ones(1,Hp)) zeros(Hp,Hp+1) -diag(ones(1,Hp)) zeros(Hp,Hp)];
Aeq = [Aeq; zeros(Hp,Hp)      diag(ones(1,Hp)) M              zeros(Hp,Hp)      zeros(Hp,Hp)];
Aeq = [Aeq; zeros(Hp,Hp)      zeros(Hp,Hp)     zeros(Hp,Hp+1) diag(ones(1,Hp))  -diag(ones(1,Hp)) ];
beq = zeros(size(Aeq,1)-Hp,1);
beq = [beq; profil_poboru(1:Hp)'];

%ograniczenia nierownosciowe - ograniczenie predkosci narastania pompy i
%predkosci zmian przeplywu przez rozdzielacz
M1 =  diag(ones(1,Hp-1)); M1 = [M1 zeros(Hp-1,1)];
M2 =  -diag(ones(1,Hp-1)); M2 = [zeros(Hp-1,1) M2];
M = M1 + M2; 
M1 =  -diag(ones(1,Hp-1)); M1 = [M1 zeros(Hp-1,1)];
M2 =  diag(ones(1,Hp-1)); M2 = [zeros(Hp-1,1) M2];
M = [M; M1 + M2];
A = [M zeros(2*(Hp-1),4*Hp+1)];
A = [A; zeros(2*(Hp-1),Hp) M zeros(2*(Hp-1),3*Hp+1)];
b=[dP*ones(2*(Hp-1),1); dZ*ones(2*(Hp-1),1)];

% Ograniczenia warości zmiennych: przedział zmienności sterowań,
% ograniczenia na stan wody w chwili t0, ograniczenie na stan wody w zbiorniku,
% ograniczenie na stan wody w chwili t0+Hp, ograniczenia na ilośc
% pobieranej wody przez odbiorców SW
lb = [Pmin*ones(1,Hp) Zmin*ones(1,Hp) V0_double Vmin*ones(1,Hp-1) V0_double-eps_V0 zeros(1,Hp)            -inf * ones(1,Hp)];
ub = [Pmax*ones(1,Hp) Zmax*ones(1,Hp) V0_double Vmax*ones(1,Hp-1) V0_double+eps_V0 (Pmax+Zmax)*ones(1,Hp)  inf * ones(1,Hp)];

%Macierze H i f do minimalizowanego kryterium min(xHx+xf)
H = diag([w_u*profil_koszt(1:Hp) zeros(1,Hp) zeros(1,Hp+1) zeros(1,Hp) w_q*ones(1,Hp)]);
%H = diag([w_u*profil_koszt zeros(1,Hp) zeros(1,Hp+1) zeros(1,Hp) w_q*ones(1,Hp)]);
f = zeros(1,Hp*5+1);
% Paramery procedury quadprog
opcje=optimset('MaxIter',1e7,'Display','off','LargeScale','off', 'Algorithm', 'interior-point-convex');
% Rozwiazania zadania optymalizacji
[x F]= quadprog(H,f,A,b,Aeq,beq,lb,ub,[],opcje);

%przypisanie wynikow
U=[x(1:Hp) x(Hp+1:2*Hp)];
traj_zbiornik = x(2*Hp+1:3*Hp+1);
q=x(3*Hp+2:4*Hp+1);
koszt = profil_koszt(1:Hp)*U(:,1);
bledy = x(4*Hp+2:end);

