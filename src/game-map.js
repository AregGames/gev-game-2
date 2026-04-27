export class GameMap {
    constructor(width, height, tileSize) {
        this.width = width;
        this.height = height;
        this.tileSize = tileSize;
        this.tiles = [];
        this.generateMaze();
    }

    generateMaze() {
        const cols = Math.floor(this.width / this.tileSize);
        const rows = Math.floor(this.height / this.tileSize);

        this.tiles = [];
        for (let i = 0; i < rows; i++) {
            this.tiles[i] = [];
            for (let j = 0; j < cols; j++) {
                if (i === 0 || i === rows - 1 || j === 0 || j === cols - 1) {
                    this.tiles[i][j] = 1;
                } else if ((i % 3 === 0 && j % 4 === 0) || (i % 4 === 0 && j % 3 === 0)) {
                    this.tiles[i][j] = Math.random() > 0.7 ? 1 : 0;
                } else {
                    this.tiles[i][j] = 0;
                }
            }
        }

        this.tiles[1][1] = 0;
        this.tiles[rows - 2][cols - 2] = 0;
    }

    isWalkable(x, y) {
        const col = Math.floor(x / this.tileSize);
        const row = Math.floor(y / this.tileSize);

        if (row < 0 || row >= this.tiles.length || col < 0 || col >= this.tiles[0].length) {
            return false;
        }

        return this.tiles[row][col] === 0;
    }

    draw(ctx) {
        for (let i = 0; i < this.tiles.length; i++) {
            for (let j = 0; j < this.tiles[i].length; j++) {
                const x = j * this.tileSize;
                const y = i * this.tileSize;

                if (this.tiles[i][j] === 1) {
                    ctx.fillStyle = '#4a4a4a';
                    ctx.fillRect(x, y, this.tileSize, this.tileSize);
                    ctx.strokeStyle = '#7a7a7a';
                    ctx.lineWidth = 1;
                    ctx.strokeRect(x, y, this.tileSize, this.tileSize);
                } else {
                    ctx.fillStyle = '#171717';
                    ctx.fillRect(x, y, this.tileSize, this.tileSize);
                }
            }
        }

        const exitCol = Math.floor(this.width / this.tileSize) - 2;
        const exitRow = Math.floor(this.height / this.tileSize) - 2;
        const exitX = exitCol * this.tileSize;
        const exitY = exitRow * this.tileSize;

        ctx.fillStyle = '#00ff00';
        ctx.fillRect(exitX, exitY, this.tileSize, this.tileSize);
        ctx.font = 'bold 12px Arial';
        ctx.fillStyle = '#000000';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('EXIT', exitX + this.tileSize / 2, exitY + this.tileSize / 2);
    }

    getExitPosition() {
        const cols = Math.floor(this.width / this.tileSize);
        const rows = Math.floor(this.height / this.tileSize);
        return {
            x: (cols - 2) * this.tileSize + this.tileSize / 2,
            y: (rows - 2) * this.tileSize + this.tileSize / 2
        };
    }
}
