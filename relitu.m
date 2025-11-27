clear;
clc;
close all;

% 环形跑道参数
race_radius = 100;   % 跑道的半径（米）
race_width = 5;      % 跑道宽度（米）
num_athletes = 50;   % 运动员数量
num_spectators = 200;% 观众基础数量
min_speed_kmh = 7;   % 最小速度 (km/h)
max_speed_kmh = 12;  % 最大速度 (km/h)
spectator_radius_offset = 10; % 观众距离跑道的最小偏移（米）

% 时间步长和模拟时间
time_step = 1;  % 1秒的时间步长
num_steps = 1000;  % 1000步模拟

% 将速度从 km/h 转换为 m/s
min_speed_mps = min_speed_kmh / 3.6;
max_speed_mps = max_speed_kmh / 3.6;

% 热力图的网格大小
grid_size = 200;  % 将跑道区域划分为 grid_size x grid_size 的网格

% 运动员初始位置和线速度
athletes = struct();
for i = 1:num_athletes
    athletes(i).angle = 0;  % 所有运动员从角度为0（即起点）开始
    athletes(i).radius = race_radius - (rand() * race_width); % 随机分布在跑道上
    athletes(i).speed = min_speed_mps + (max_speed_mps - min_speed_mps) * rand();  % 随机速度（线速度 m/s）
    athletes(i).color = rand(1, 3);  % 随机颜色
    athletes(i).completed_lap = false; % 标记运动员是否完成了一圈
end

% 观众初始位置（沿着跑道两侧分布）
spectators = struct();
for i = 1:num_spectators
    spectators(i).angle = 2 * pi * rand();  % 随机分布在圆周上
    if rand() > 0.5
        spectators(i).radius = race_radius + spectator_radius_offset + rand();  % 观众在跑道外侧
    else
        spectators(i).radius = race_radius - spectator_radius_offset - rand();  % 观众在跑道内侧
    end
    spectators(i).density = 1; % 初始观众密度
    spectators(i).color = [0.5, 0.5, 0.5];  % 观众颜色为灰色
end

% 创建图形窗口，设置为双子图：一个用于轨迹，另一个用于热力图
figure;

subplot(1, 2, 1);  % 左侧子图用于运动员轨迹
hold on;
axis equal;
axis([-race_radius-20 race_radius+20 -race_radius-20 race_radius+20]);
xlabel('X  (m)');
ylabel('Y  (m)');
title('Circular Track Simulation + Heat Map');

subplot(1, 2, 2);  % 右侧子图用于热力图
x_grid = linspace(-race_radius-20, race_radius+20, grid_size);
y_grid = linspace(-race_radius-20, race_radius+20, grid_size);
heatmap_data = zeros(grid_size, grid_size);  % 用于存储运动员和观众的密度
h = imagesc(x_grid, y_grid, heatmap_data);
set(gca,'YDir','normal');  % 修正 Y 轴方向
colorbar;
axis equal;
title('Crowd Density Heat Map');
xlabel('X  (m)');
ylabel('Y  (m)');

% 动画循环
for step = 1:num_steps
    % 清空热力图数据
    heatmap_data = zeros(grid_size, grid_size);
    
    % 绘制环形赛道
    subplot(1, 2, 1);  % 切换到轨迹子图
    cla;  % 清除当前图形内容
    theta = linspace(0, 2 * pi, 100);  % 圆周的角度
    x_outer = (race_radius + race_width) * cos(theta);  % 外侧边界
    y_outer = (race_radius + race_width) * sin(theta);
    x_inner = (race_radius - race_width) * cos(theta);  % 内侧边界
    y_inner = (race_radius - race_width) * sin(theta);
    fill([x_outer, fliplr(x_inner)], [y_outer, fliplr(y_inner)], [0.8, 0.8, 0.8]);  % 绘制跑道
    hold on;
    
    % 计算每个运动员当前位置并更新轨迹
    athlete_positions = zeros(num_athletes, 2);  % 保存运动员的当前位置
    for i = 1:num_athletes
        if ~athletes(i).completed_lap
            % 更新运动员角度
            angular_speed = athletes(i).speed / athletes(i).radius;
            athletes(i).angle = mod(athletes(i).angle + angular_speed * time_step, 2 * pi);
            
            % 检查运动员是否完成了一圈
            if abs(athletes(i).angle - 0) < angular_speed * time_step
                athletes(i).completed_lap = true;
            end
        end
        
        % 计算运动员的坐标
        athlete_x = athletes(i).radius * cos(athletes(i).angle);
        athlete_y = athletes(i).radius * sin(athletes(i).angle);
        athlete_positions(i, :) = [athlete_x, athlete_y];
        
        % 绘制运动员
        plot(athlete_x, athlete_y, 'o', 'MarkerSize', 8, 'MarkerEdgeColor', athletes(i).color, 'MarkerFaceColor', athletes(i).color);
        
        % 将运动员的坐标映射到热力图网格
        x_idx = find(x_grid >= athlete_x, 1, 'first');
        y_idx = find(y_grid >= athlete_y, 1, 'first');
        if ~isempty(x_idx) && ~isempty(y_idx)
            heatmap_data(y_idx, x_idx) = heatmap_data(y_idx, x_idx) + 1;  % 增加运动员密度
        end
    end
    
    % 更新观众位置并更新热力图
    for i = 1:num_spectators
        % 动态改变观众密度，运动员越接近观众点，观众密度越大
        min_dist = inf;
        for j = 1:num_athletes
            dist = sqrt((spectators(i).radius * cos(spectators(i).angle) - athlete_positions(j, 1))^2 + ...
                        (spectators(i).radius * sin(spectators(i).angle) - athlete_positions(j, 2))^2);
            if dist < min_dist
                min_dist = dist;
            end
        end
        
        % 根据最小距离调整观众密度
        if min_dist < 20  % 距离小于20米时观众聚集
            spectators(i).density = 5;  % 增加观众数量
        elseif min_dist < 50  % 距离稍远时观众数量正常
            spectators(i).density = 3;
        else
            spectators(i).density = 1;  % 运动员离开，观众稀疏
        end
        
        % 计算观众的坐标
        spectator_x = spectators(i).radius * cos(spectators(i).angle);
        spectator_y = spectators(i).radius * sin(spectators(i).angle);
        
        % 绘制观众
        plot(spectator_x, spectator_y, 'o', 'MarkerSize', spectators(i).density * 3, 'MarkerEdgeColor', spectators(i).color, 'MarkerFaceColor', spectators(i).color);
        
        % 将观众的坐标映射到热力图网格
        x_idx = find(x_grid >= spectator_x, 1, 'first');
        y_idx = find(y_grid >= spectator_y, 1, 'first');
        if ~isempty(x_idx) && ~isempty(y_idx)
            heatmap_data(y_idx, x_idx) = heatmap_data(y_idx, x_idx) + spectators(i).density;  % 增加观众密度
        end
    end
    % 检查是否所有运动员都完成了一圈
    if all([athletes.completed_lap])
        disp('All athletes have completed one lap！');
        break;  % 结束循环
    end
    
    % 更新热力图
    subplot(1, 2, 2);  % 切换到热力图子图
    set(h, 'CData', heatmap_data);  % 更新热力图数据
    drawnow;  % 更新图形显示
end
