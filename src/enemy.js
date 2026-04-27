export class Enemy {
    constructor(x, y, size, map, player) {
        this.x = x;
        this.y = y;
        this.size = size;
        this.map = map;
        this.player = player;
        this.speed = 90;
        this.visionRange = 150;
        this.isAggressive = false;
    }

    update(deltaTime) {
        const distance = this.distanceTo(this.player.x, this.player.y);

        if (distance < this.visionRange) {
            this.isAggressive = true;
            this.moveTowards(this.player.x, this.player.y, deltaTime);
        } else {
            this.isAggressive = false;
            this.randomWalk(deltaTime);
        }

        this.x = Math.max(this.size / 2, Math.min(this.x, this.map.width - this.size / 2));
        this.y = Math.max(this.size / 2, Math.min(this.y, this.map.height - this.size / 2));
    }

    moveTowards(targetX, targetY, deltaTime) {
        const dx = targetX - this.x;
        const dy = targetY - this.y;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance > 0) {
            const moveDistance = this.speed * deltaTime;
            const moveX = (dx / distance) * moveDistance;
            const moveY = (dy / distance) * moveDistance;

            const nextX = this.x + moveX;
            if (this.isWalkable(nextX, this.y)) {
                this.x = nextX;
            }

            const nextY = this.y + moveY;
            if (this.isWalkable(this.x, nextY)) {
                this.y = nextY;
            }
        }
    }

    randomWalk(deltaTime) {
        if (Math.random() < 3 * deltaTime) {
            const angle = Math.random() * Math.PI * 2;
            const moveDistance = this.speed * deltaTime;
            const moveX = Math.cos(angle) * moveDistance;
            const moveY = Math.sin(angle) * moveDistance;

            if (this.isWalkable(this.x + moveX, this.y + moveY)) {
                this.x += moveX;
                this.y += moveY;
            }
        }
    }

    isWalkable(x, y) {
        return this.map.isWalkable(x - this.size / 2, y - this.size / 2) &&
               this.map.isWalkable(x + this.size / 2, y - this.size / 2) &&
               this.map.isWalkable(x - this.size / 2, y + this.size / 2) &&
               this.map.isWalkable(x + this.size / 2, y + this.size / 2);
    }

    draw(ctx) {
        ctx.fillStyle = this.isAggressive ? '#ff0000' : '#ff6600';

        ctx.fillRect(this.x - this.size / 2, this.y - this.size / 2, this.size, this.size);

        ctx.fillStyle = '#ffff00';
        ctx.fillRect(this.x - this.size / 4, this.y - this.size / 4, 4, 4);
        ctx.fillRect(this.x + this.size / 4, this.y - this.size / 4, 4, 4);
    }

    distanceTo(x, y) {
        const dx = this.x - x;
        const dy = this.y - y;
        return Math.sqrt(dx * dx + dy * dy);
    }

    collidesWith(x, y, size) {
        const dx = this.x - x;
        const dy = this.y - y;
        const distance = Math.sqrt(dx * dx + dy * dy);
        return distance < (this.size + size) / 2;
    }
}
