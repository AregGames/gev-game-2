export class Player {
    constructor(x, y, size, map) {
        this.x = x;
        this.y = y;
        this.size = size;
        this.map = map;
        this.speed = 180;
        this.vx = 0;
        this.vy = 0;
        this.health = 3;
        this.isAlive = true;
    }

    update(keys, deltaTime) {
        let newVx = 0;
        let newVy = 0;
        const moveDistance = this.speed * deltaTime;

        if (keys.w || keys.ArrowUp) {
            newVy = -moveDistance;
        }
        if (keys.s || keys.ArrowDown) {
            newVy = moveDistance;
        }
        if (keys.a || keys.ArrowLeft) {
            newVx = -moveDistance;
        }
        if (keys.d || keys.ArrowRight) {
            newVx = moveDistance;
        }

        if (newVx !== 0) {
            const nextX = this.x + newVx;
            if (this.isWalkable(nextX, this.y)) {
                this.x = nextX;
            }
        }

        if (newVy !== 0) {
            const nextY = this.y + newVy;
            if (this.isWalkable(this.x, nextY)) {
                this.y = nextY;
            }
        }

        this.x = Math.max(this.size / 2, Math.min(this.x, this.map.width - this.size / 2));
        this.y = Math.max(this.size / 2, Math.min(this.y, this.map.height - this.size / 2));
    }

    isWalkable(x, y) {
        return this.map.isWalkable(x - this.size / 2, y - this.size / 2) &&
               this.map.isWalkable(x + this.size / 2, y - this.size / 2) &&
               this.map.isWalkable(x - this.size / 2, y + this.size / 2) &&
               this.map.isWalkable(x + this.size / 2, y + this.size / 2);
    }

    takeDamage() {
        this.health--;
        if (this.health <= 0) {
            this.isAlive = false;
        }
    }

    draw(ctx) {
        ctx.fillStyle = '#00ff88';
        ctx.fillRect(this.x - this.size / 2, this.y - this.size / 2, this.size, this.size);

        ctx.fillStyle = '#000000';
        ctx.fillRect(this.x - this.size / 4, this.y - this.size / 4, 4, 4);
        ctx.fillRect(this.x + this.size / 4, this.y - this.size / 4, 4, 4);
    }

    distanceTo(x, y) {
        const dx = this.x - x;
        const dy = this.y - y;
        return Math.sqrt(dx * dx + dy * dy);
    }
}
