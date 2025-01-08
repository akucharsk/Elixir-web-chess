
class Time {
    static SECOND = 1000;
    static MINUTE = Time.SECOND * 60;
    static HOUR = Time.MINUTE * 60;
    static DAY = Time.HOUR * 24;

    constructor(
        {
            days: days = 0,
            hours: hours = 0,
            minutes: minutes = 10,
            seconds: seconds = 0,
            milliseconds: milliseconds = 0
        } = {}) {
        this.days = days;
        this.hours = hours;
        this.minutes = minutes;
        this.seconds = seconds;
        this.milliseconds = milliseconds;
    }

    static fromDatetime(datetime) {
        if (datetime < 0) {
            datetime = 0;
        }
        const milliseconds = datetime % 1000;
        const seconds = Math.floor(datetime / Time.SECOND) % 60;
        const minutes = Math.floor(datetime / Time.MINUTE) % 60;
        const hours = Math.floor(datetime / Time.HOUR) % 24;
        const days = Math.floor(datetime / Time.DAY);

        return new Time({
            days: days,
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
        })
    }

    static fromElixir(elixirTime) {
        let splitTime = elixirTime.split(":");
        splitTime[2] = splitTime[2].split(".");
        splitTime = splitTime.flat().map(time => parseInt(time));

        return new Time({
            days: 0,
            hours: splitTime[0],
            minutes: splitTime[1],
            seconds: splitTime[2],
            milliseconds: splitTime[3],
        })
    }

    static currentTime() {
        return Time.fromDatetime(Date.now());
    }

    toString() {
        const days = this.days > 0 ? `${this.days}d ` : '';
        const hours = this.hours > 0 ? `${String(this.hours).padStart(2, '0')}:` : '';
        const minutes = String(this.minutes).padStart(2, '0');
        const seconds = String(this.seconds).padStart(2, '0');
        const milliseconds = 
            this.days === 0 && this.hours === 0 && this.minutes === 0 ? `:${String(this.milliseconds).padStart(3, '0')}` : '';

        return `${days}${hours}${minutes}:${seconds}${milliseconds}`;
    }

    toUnitTime() {
        return this.days * Time.DAY + this.hours * Time.HOUR + this.minutes * Time.MINUTE + this.seconds * Time.SECOND + this.milliseconds;
    }

    timeout() {
        return this.toUnitTime() === 0;
    }

    static unitTimeSubtract(time1, time2) {
        if (!Number.isInteger(time1)) {
            time1 = time1.toUnitTime();
        }
        if (!Number.isInteger(time2)) {
            time2 = time2.toUnitTime();
        }

        return time1 - time2;
    }

    static subtract(time1, time2) {
        return Time.fromDatetime(Time.unitTimeSubtract(time1, time2));
    }

}

export class Timer {
    constructor(whiteTimer, blackTimer) {
        this.currentTime = Time.currentTime();

        this.whiteRemainingTime = new Time();
        this.blackRemainingTime = new Time();

        this.whiteTimer = whiteTimer;
        this.blackTimer = blackTimer;

        this.whiteTimer.defaultColor = "#000000";
        this.blackTimer.defaultColor = "#000000";

        this.turn = "white";
    }

    updateTimer() {
        if (this.turn === "white") {
            this.whiteRemainingTime = 
                Time.subtract(this.whiteRemainingTime, Time.subtract(Date.now(), this.currentTime));
            if (this.whiteRemainingTime.minutes === 0 && this.whiteRemainingTime.seconds < 30) {
                this.whiteTimer.style.color = "#ff0000";
            }
        } else {
            this.blackRemainingTime = 
                Time.subtract(this.blackRemainingTime, Time.subtract(Date.now(), this.currentTime));
            if (this.blackRemainingTime.minutes === 0 && this.blackRemainingTime.seconds < 30) {
                this.blackTimer.style.color = "#ff0000";
            }
        }
        
        this.currentTime = Time.currentTime();
        this.whiteTimer.textContent = `${this.whiteRemainingTime.toString()}`;
        this.blackTimer.textContent = `${this.blackRemainingTime.toString()}`;

        if (this.whiteRemainingTime.timeout()) {
            this.clearInterval();
            window.dispatchEvent(new CustomEvent("white:timeout"));
        } else if (this.blackRemainingTime.timeout()) {
            this.clearInterval();
            window.dispatchEvent(new CustomEvent("black:timeout"));
        }
    }

    synchronizeWithServerTime(whiteTime, blackTime) {
        const whiteRemainingTime = Time.fromElixir(whiteTime);
        const blackRemainingTime = Time.fromElixir(blackTime);
        if (Math.abs(Time.unitTimeSubtract(whiteRemainingTime, this.whiteRemainingTime)) > 50) {
            this.whiteRemainingTime = whiteRemainingTime;
        }
        if (Math.abs(Time.unitTimeSubtract(blackRemainingTime, this.blackRemainingTime)) > 50) {
            this.blackRemainingTime = blackRemainingTime;
        }
    }

    startTimer() {
        this.currentTime = Time.currentTime();
        this.interval = setInterval(this.updateTimer.bind(this), 1);
    }

    clearInterval() {
        clearInterval(this.interval);
    }

    switchTimer() {
        this.turn = this.turn === "white" ? "black" : "white";
        this.currentTime = Time.currentTime();
    }
}
