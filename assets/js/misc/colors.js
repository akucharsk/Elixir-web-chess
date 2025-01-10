
export default class Color{
    constructor({red: red = 0, green: green = 0, blue: blue = 0, alpha: alpha = 255} = {}) { 
        this.red = red;
        this.green = green;
        this.blue = blue;
        this.alpha = alpha;
    }

    static RED() {
        return new Color({red: 255, green: 0, blue: 0});
    }

    static GREEN() {
        return new Color({red: 0, green: 255, blue: 0});
    }

    static BLUE() {
        return new Color({red: 0, green: 0, blue: 255});
    }

    static YELLOW() {
        return new Color({red: 255, green: 255, blue: 0});
    }

    static CYAN() {
        return new Color({red: 0, green: 255, blue: 255});
    }

    static MAGENTA() {
        return new Color({red: 255, green: 0, blue: 255});
    }

    static BLACK() {
        return new Color({red: 0, green: 0, blue: 0});
    }

    static WHITE() {
        return new Color({red: 255, green: 255, blue: 255});
    }

    static fromHex(hex) {
        let red = parseInt(hex.substring(1, 3), 16);
        let green = parseInt(hex.substring(3, 5), 16);
        let blue = parseInt(hex.substring(5, 7), 16);
        return new Color({red: red, green: green, blue: blue});
    }

    static fromRGB(rgb) {
        let color = rgb.match(/\d+/g).map(Number);
        return new Color({red: color[0], green: color[1], blue: color[2]});
    }

    average(color) {
        return new Color({
            red: (this.red + color.red) / 2,
            green: (this.green + color.green) / 2,
            blue: (this.blue + color.blue) / 2,
            alpha: (this.alpha + color.alpha) / 2,
        })
    }

    weightedAverage(color, selfWeight, otherWeight) {
        return new Color({
            red: (this.red * selfWeight + color.red * otherWeight) / (selfWeight + otherWeight),
            green: (this.green * selfWeight + color.green * otherWeight) / (selfWeight + otherWeight),
            blue: (this.blue * selfWeight + color.blue * otherWeight) / (selfWeight + otherWeight),
            alpha: (this.alpha * selfWeight + color.alpha * otherWeight) / (selfWeight + otherWeight),
        })
    }

    toHex() {
        const red = Math.floor(this.red);
        const green = Math.floor(this.green);
        const blue = Math.floor(this.blue);
        return `#${red.toString(16)}${green.toString(16)}${blue.toString(16)}`;
    }

    toRGB() {
        const red = Math.floor(this.red);
        const green = Math.floor(this.green);
        const blue = Math.floor(this.blue);
        return `rgb(${red}, ${green}, ${blue})`;
    }

}