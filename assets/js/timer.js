
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
        const milliseconds = datetime % 1000;
        const seconds = Math.floor(datetime / Time.SECOND) % 60;
        const minutes = Math.floor(datetime / Time.MINUTE) % 60;
        const hours = Math.floor(datetime / Time.HOUR) % 60;
        const days = Math.floor(datetime / Time.DAY);

        return new Time({
            days: days,
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
        })
    }

    static currentTime() {
        return Time.fromDatetime(Date.now());
    }

    toString() {
        const days = this.days > 0 ? `${this.days}d ` : '';
        const hours = this.hours > 0 ? `${String(this.hours).padStart(2, '0')}:` : '';
        const milliseconds = 
            this.days === 0 && this.hours === 0 && this.minutes === 0 ? `:${String(this.milliseconds).padStart(3, '0')}` : '';
        return `${days}${hours}${String(this.minutes).padStart(2, '0')}:${String(this.seconds).padStart(2, '0')}${milliseconds}`;
    }

    toUnitTime() {
        return this.days * Time.DAY + this.hours * Time.HOUR + this.minutes * Time.MINUTE + this.seconds * Time.SECOND + this.milliseconds;
    }

    static difference(time1, time2) {
        if (!Number.isInteger(time1)) {
            time1 = time1.toUnitTime();
        }
        if (!Number.isInteger(time2)) {
            time2 = time2.toUnitTime();
        }
        return Time.fromDatetime(time1 - time2);
    }
}

export class Timer {
    constructor(whiteTimer, blackTimer) {
        this.currentTime = Time.currentTime();
        this.remainingTime = new Time();
        this.whiteTimer = whiteTimer;
        this.blackTimer = blackTimer;

        this.currentTimer = this.whiteTimer;
    }

    updateTimer() {
        this.remainingTime = Time.difference(this.remainingTime, Time.difference(Date.now(), this.currentTime));
        this.currentTime = Time.currentTime();
        this.currentTimer.textContent = this.remainingTime.toString();
    }

    startTimer() {
        this.currentTime = Time.currentTime();
        this.interval = setInterval(this.updateTimer.bind(this), 1);
    }
}
