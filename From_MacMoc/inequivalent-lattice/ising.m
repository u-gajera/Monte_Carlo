function [Ms, Cs, Mx, Es, time1] = ising(model,Lat,J1,J2,J3,D,Sp,L,estep,mstep,Ts,para,kb)
%global model Lat J1 J2 J3 Sp L estep mstep Ts para kb

Ms = zeros(1, size(Ts,2));
Mx = zeros(1, size(Ts,2));
Es = zeros(1, size(Ts,2));
Cs = zeros(1, size(Ts,2));
const = [];
time1 = 0; time2 = 0; time3 = 0;

%% Generate a random initial configuration of spin 1
initiate = Sp .* ((rand(L) > 0.5)*2 - 1);
grid = zeros(L);                           % move into parfor if parellel
grid(:,:) = initiate(:,:) ;  %deep copy?   % move into parfor if parellel   

%% Generate zero and ones matrix
aones = zeros(L);
for i = 1:L
    for j = 1:L
        if mod(i-j,2)==1
        aones(i,j)=0;
        else
        aones(i,j)=1;
        end
    end
end
bar = waitbar(0,'1','Name','Monte-Carlo');
%% Evolve the system for a fixed number of steps
for t = 1:size(Ts,2)   %change into parfor if parellel
    E0 = 0.0; E1 = 0.0; E2 = 0.0; M0 = 0.0; M1 = 0.0; M2 = 0.0;
    const = 1 / (L^2 * Ts(t) * kb) ;  % factor to be used in specific heat
    %grid = zeros(L);                           % move into parfor if parellel
    %grid(:,:) = initiate(:,:) ;  % deep copy?  % move into parfor if parellel
    str=['Calculating: ',num2str(Ts(t)),'K' , ...
         ' (',num2str(100*t/size(Ts,2)),'%) ', ...
         num2str((size(Ts,2)-t)*time3/60), ' min left'];
    waitbar(t/size(Ts,2),bar,str)
    
    tic
    for i=1:(estep+mstep)
    % Pick a random spin
    row = randi(L);   % or : linearIndex = randi(numel(grid));
    col = randi(L);   % or : [row, col]  = ind2sub(size(grid), linearIndex);
    % Find its Fir/Sec/Thi-Nearest neighbors,
    % Calculate the number of neighbors of each cell
    gridT = - grid(row,col);
    % Calculate the change in energy of flipping a spin
    neighbors1=[]; neighbors2=[]; neighbors3=[];
    above1 = mod(row - 1 - 1, size(grid,1)) + 1;
    below1 = mod(row + 1 - 1, size(grid,1)) + 1;
    left1  = mod(col - 1 - 1, size(grid,2)) + 1;
    right1 = mod(col + 1 - 1, size(grid,2)) + 1;
    
    above2 = mod(row - 1 - 2, size(grid,1)) + 1;
    below2 = mod(row + 2 - 1, size(grid,1)) + 1;
    left2  = mod(col - 1 - 2, size(grid,2)) + 1;
    right2 = mod(col + 2 - 1, size(grid,2)) + 1;
    
    if Lat == 'c'
        neighbors1 = grid(above1,    col) + ...
                     grid(below1,    col) ;
        neighbors2 = grid(row,     left1) + ...
                     grid(row,    right1) ;
        neighbors3 = grid(above1,  left1) + ...
                     grid(above1, right1) + ...
                     grid(below1,  left1) + ...
                     grid(below1, right1) ;
    end
    
    % Calculate the change in energy of turning a spin to a random direction
    E  = - 2 * sum(gridT.*(J1 .* neighbors1 + J2 .* neighbors2 + J3 .* neighbors3)) ;
    dE =   2 * E;
    % Transition probabilities and performed on the chosen spin
    if dE < 0
        transition = -1;
    else
        transition = (rand() < exp(-dE/(kb*Ts(t)))) * -2 + 1;
    end
    grid(row, col) = grid(row, col) * transition;
    
    % Calculate total E - short cut
    if i == estep
        % Calculate initial energy
        if Lat == 'c'
            shift1 = circshift(grid, [ 0  1]) ;
            shift2 = circshift(grid, [ 1  0]) ;
            shift3 = circshift(grid, [ 1  1]) + ...
                     circshift(grid, [ 1 -1]) ;
            Eini = -2*sum(sum(sum(grid       .* ...
                                 (J1 * shift1 + ...
                                  J2 * shift2 + ...
                                  J3 * shift3 ))));
        end
    E0 =  Eini ;
    end
    
    if i > estep ; % E0: the total energy of step i
        E0 =  E0 + dE * (transition == -1);
        % calculate average M per site
        E1 =  E1 + E0          ;
        E2 =  E2 + E0^2        ;
        
        M0 =  2*sum(sum(grid)) ;
        M1 =  M1 + M0          ;
        M2 =  M2 + M0^2        ;
        M0 =  0.0              ;
    end
    % Display the current state of the system (optional)
    %image((grid+1)*128);
    %%xlabel(sprintf('t = %0.2f, M = %0.2f, E = %0.2f', T, M/L^2, E/L^2));
    %set(gca,'YTickLabel',[],'XTickLabel',[]);
    %axis square; colormap bone; drawnow;    
    end
    time2 = toc                    ;
    time1 = time1 + time2          ;
    time3 = (time2 + time3*(t-1))/t;
    % Sum up our variables of interest    
    Ms(t) = abs(M1)/(mstep*L^2); 
    Mx(t) = (M2/mstep-(M1/mstep)^2)*const;
    Cs(t) = (E2/mstep-(E1/mstep)^2)*const/Ts(t);
    Es(t) =  E1/(mstep*L^2);
    E0 = 0.0; E1 = 0.0; E2 = 0.0;
    M1 = 0.0; M2 = 0.0;
end
close(bar)
% Count the number of clusters of 'spin up' states
%[L, num] = bwlabel(grid == 1, 4);