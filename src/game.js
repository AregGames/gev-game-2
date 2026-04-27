import { Enemy } from './enemy.js';
import { GameMap } from './game-map.js';
import { Player } from './player.js';

export class Game {
    constructor() {
        this.canvas = document.getElementById('gameCanvas');
        this.ctx = this.canvas.getContext('2d');
        this.canvasWidth = this.canvas.width;
        this.canvasHeight = this.canvas.height;
        this.tileSize = 50;
        this.lightRange = 430;
        this.lightSpread = Math.PI / 4.5;
        this.playerGlowRadius = 70;

        this.gameState = 'playing';
        this.currentLevel = 1;
        this.time = 0;
        this.keys = {};
        this.mouse = { x: this.canvasWidth, y: this.canvasHeight / 2 };
        this.restartAt = null;
        this.lastFrameTime = performance.now();

        this.resetGame();
        this.setupEventListeners();
        this.gameLoop();
    }

    resetGame() {
        this.gameState = 'playing';
        this.time = 0;
        this.restartAt = null;
        this.map = new GameMap(this.canvasWidth, this.canvasHeight, this.tileSize);
        this.buildMapLayer();
        this.fogCanvas = this.createCanvasLayer();
        this.fogCtx = this.fogCanvas.getContext('2d');
        this.player = this.createPlayer();
        this.enemies = [];

        this.spawnEnemies();
    }

    buildMapLayer() {
        this.mapCanvas = this.createCanvasLayer();

        const mapCtx = this.mapCanvas.getContext('2d');
        this.map.draw(mapCtx);
    }

    createCanvasLayer() {
        const layer = document.createElement('canvas');
        layer.width = this.canvasWidth;
        layer.height = this.canvasHeight;
        return layer;
    }

    createPlayer() {
        return new Player(
            this.tileSize * 1.5,
            this.tileSize * 1.5,
            15,
            this.map
        );
    }

    spawnEnemies() {
        const spawnPositions = [
            { x: this.canvasWidth - 100, y: 100 },
            { x: 100, y: this.canvasHeight - 100 },
            { x: this.canvasWidth - 100, y: this.canvasHeight - 100 },
        ];

        this.enemies = spawnPositions.map(pos =>
            new Enemy(pos.x, pos.y, 15, this.map, this.player)
        );

        for (let i = 0; i < this.currentLevel; i++) {
            const randomX = Math.random() * (this.canvasWidth - 200) + 100;
            const randomY = Math.random() * (this.canvasHeight - 200) + 100;
            this.enemies.push(new Enemy(randomX, randomY, 15, this.map, this.player));
        }
    }

    setupEventListeners() {
        window.addEventListener('keydown', (e) => {
            this.keys[e.key] = true;
            this.keys[e.key.toLowerCase()] = true;
        });

        window.addEventListener('keyup', (e) => {
            this.keys[e.key] = false;
            this.keys[e.key.toLowerCase()] = false;
        });

        this.canvas.addEventListener('mousemove', (e) => {
            const rect = this.canvas.getBoundingClientRect();
            const scaleX = this.canvas.width / rect.width;
            const scaleY = this.canvas.height / rect.height;

            this.mouse.x = (e.clientX - rect.left) * scaleX;
            this.mouse.y = (e.clientY - rect.top) * scaleY;
        });
    }

    update(deltaTime) {
        if (this.gameState !== 'playing') return;

        this.player.update(this.keys, deltaTime);
        this.enemies.forEach(enemy => enemy.update(deltaTime));

        this.enemies.forEach(enemy => {
            if (enemy.collidesWith(this.player.x, this.player.y, this.player.size)) {
                this.player.takeDamage();
                if (!this.player.isAlive) {
                    this.gameState = 'gameOver';
                    this.restartAt = performance.now() + 1500;
                }
            }
        });

        const exit = this.map.getExitPosition();
        const distToExit = this.player.distanceTo(exit.x, exit.y);
        if (distToExit < 30) {
            this.gameState = 'won';
        }

        this.time += deltaTime;
    }

    draw() {
        this.ctx.fillStyle = '#000000';
        this.ctx.fillRect(0, 0, this.canvasWidth, this.canvasHeight);

        this.ctx.drawImage(this.mapCanvas, 0, 0);
        this.enemies.forEach(enemy => enemy.draw(this.ctx));
        this.player.draw(this.ctx);
        this.drawFogOfWar();
        this.drawVisibleLight(this.getLightAngle());
        this.drawPlayerAboveFog();
        this.drawUI();
    }

    drawFogOfWar() {
        const lightAngle = this.getLightAngle();
        const previousCtx = this.ctx;

        this.ctx = this.fogCtx;
        this.ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
        this.ctx.save();
        this.ctx.globalCompositeOperation = 'source-over';
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.96)';
        this.ctx.fillRect(0, 0, this.canvasWidth, this.canvasHeight);

        this.ctx.globalCompositeOperation = 'destination-out';
        this.cutPlayerGlow();
        this.cutLightCone(lightAngle);
        this.ctx.restore();
        this.ctx = previousCtx;
        this.ctx.drawImage(this.fogCanvas, 0, 0);
    }

    getLightAngle() {
        return Math.atan2(this.mouse.y - this.player.y, this.mouse.x - this.player.x);
    }

    cutPlayerGlow() {
        const glow = this.ctx.createRadialGradient(
            this.player.x,
            this.player.y,
            0,
            this.player.x,
            this.player.y,
            this.playerGlowRadius
        );

        glow.addColorStop(0, 'rgba(0, 0, 0, 1)');
        glow.addColorStop(0.7, 'rgba(0, 0, 0, 0.7)');
        glow.addColorStop(1, 'rgba(0, 0, 0, 0)');

        this.ctx.fillStyle = glow;
        this.ctx.beginPath();
        this.ctx.arc(this.player.x, this.player.y, this.playerGlowRadius, 0, Math.PI * 2);
        this.ctx.fill();
    }

    cutLightCone(angle) {
        this.ctx.save();
        this.clipLightCone(angle, this.lightRange, this.lightSpread);
        this.ctx.fillStyle = '#ffffff';
        this.ctx.fillRect(0, 0, this.canvasWidth, this.canvasHeight);
        this.ctx.restore();
    }

    drawVisibleLight(angle) {
        this.ctx.save();
        this.clipLightArea(angle, this.lightRange, this.lightSpread);
        this.ctx.fillStyle = 'rgba(80, 255, 170, 0.24)';
        this.ctx.fillRect(0, 0, this.canvasWidth, this.canvasHeight);
        this.ctx.restore();

        const centerGlow = this.ctx.createRadialGradient(
            this.player.x,
            this.player.y,
            0,
            this.player.x,
            this.player.y,
            this.playerGlowRadius * 1.4
        );

        centerGlow.addColorStop(0, 'rgba(160, 255, 210, 0.28)');
        centerGlow.addColorStop(1, 'rgba(0, 255, 136, 0)');

        this.ctx.save();
        this.ctx.globalCompositeOperation = 'lighter';
        this.ctx.fillStyle = centerGlow;
        this.ctx.beginPath();
        this.ctx.arc(this.player.x, this.player.y, this.playerGlowRadius * 1.4, 0, Math.PI * 2);
        this.ctx.fill();
        this.ctx.restore();

        this.drawLightEdge(angle);
    }

    clipLightCone(angle, range, spread) {
        const leftAngle = angle - spread;
        const rightAngle = angle + spread;

        this.ctx.beginPath();
        this.ctx.moveTo(this.player.x, this.player.y);
        this.ctx.arc(this.player.x, this.player.y, range, leftAngle, rightAngle);
        this.ctx.closePath();
        this.ctx.clip();
    }

    clipLightArea(angle, range, spread) {
        const leftAngle = angle - spread;
        const rightAngle = angle + spread;

        this.ctx.beginPath();
        this.ctx.moveTo(this.player.x, this.player.y);
        this.ctx.arc(this.player.x, this.player.y, range, leftAngle, rightAngle);
        this.ctx.closePath();
        this.ctx.moveTo(this.player.x + this.playerGlowRadius, this.player.y);
        this.ctx.arc(this.player.x, this.player.y, this.playerGlowRadius, 0, Math.PI * 2);
        this.ctx.closePath();
        this.ctx.clip();
    }

    drawLightEdge(angle) {
        const edgeRange = this.lightRange * 0.75;
        const leftAngle = angle - this.lightSpread * 0.62;
        const rightAngle = angle + this.lightSpread * 0.62;

        this.ctx.save();
        this.ctx.strokeStyle = 'rgba(0, 255, 136, 0.28)';
        this.ctx.lineWidth = 1.5;
        this.ctx.beginPath();
        this.ctx.moveTo(this.player.x, this.player.y);
        this.ctx.lineTo(
            this.player.x + Math.cos(leftAngle) * edgeRange,
            this.player.y + Math.sin(leftAngle) * edgeRange
        );
        this.ctx.moveTo(this.player.x, this.player.y);
        this.ctx.lineTo(
            this.player.x + Math.cos(rightAngle) * edgeRange,
            this.player.y + Math.sin(rightAngle) * edgeRange
        );
        this.ctx.stroke();
        this.ctx.restore();
    }

    drawPlayerAboveFog() {
        this.ctx.save();
        this.ctx.shadowColor = '#00ff88';
        this.ctx.shadowBlur = 8;
        this.player.draw(this.ctx);
        this.ctx.restore();
    }

    drawUI() {
        document.getElementById('health').textContent = Math.max(0, this.player.health);
        document.getElementById('level').textContent = this.currentLevel;
        document.getElementById('time').textContent = Math.floor(this.time);

        if (this.gameState === 'gameOver') {
            this.drawGameOver();
        } else if (this.gameState === 'won') {
            this.drawWon();
        }
    }

    drawGameOver() {
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
        this.ctx.fillRect(0, 0, this.canvasWidth, this.canvasHeight);

        this.ctx.fillStyle = '#ff0000';
        this.ctx.font = 'bold 48px Arial';
        this.ctx.textAlign = 'center';
        this.ctx.textBaseline = 'middle';
        this.ctx.fillText('GAME OVER', this.canvasWidth / 2, this.canvasHeight / 2 - 40);

        this.ctx.fillStyle = '#ffffff';
        this.ctx.font = '24px Arial';
        this.ctx.fillText(`Survival time: ${Math.floor(this.time)} sec`,
            this.canvasWidth / 2, this.canvasHeight / 2 + 40);
        this.ctx.fillText('Restarting...',
            this.canvasWidth / 2, this.canvasHeight / 2 + 80);
    }

    drawWon() {
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
        this.ctx.fillRect(0, 0, this.canvasWidth, this.canvasHeight);

        this.ctx.fillStyle = '#00ff88';
        this.ctx.font = 'bold 48px Arial';
        this.ctx.textAlign = 'center';
        this.ctx.textBaseline = 'middle';
        this.ctx.fillText('YOU WIN!', this.canvasWidth / 2, this.canvasHeight / 2 - 40);

        this.ctx.fillStyle = '#ffffff';
        this.ctx.font = '24px Arial';
        this.ctx.fillText(`Completion time: ${Math.floor(this.time)} sec`,
            this.canvasWidth / 2, this.canvasHeight / 2 + 40);
        this.ctx.fillText('Press F5 to restart',
            this.canvasWidth / 2, this.canvasHeight / 2 + 80);
    }

    gameLoop = (now = performance.now()) => {
        const deltaTime = Math.min((now - this.lastFrameTime) / 1000, 0.05);
        this.lastFrameTime = now;

        if (this.gameState === 'gameOver' && performance.now() >= this.restartAt) {
            this.resetGame();
        }

        this.update(deltaTime);
        this.draw();
        requestAnimationFrame(this.gameLoop);
    };
}
