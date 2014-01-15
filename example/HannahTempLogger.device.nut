/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/*

------ [ Imp pins ] ------
Pin 1    Digital input         Interrupt from GPIO expander
Pin 2         Analog input         Potentiometer wiper
Pin 5         Digital output         Servo port 1 PWM signal
Pin 7         Digital output         Servo port 2 PWM signal
Pin 8         I2C SCL             
Pin 9         I2C SDA


------ [ I2C Addresses ] ------
0x38/0x1C   LIS331DLTR                3-Axis accelerometer
0xE8/0x74        ADJD-S311-CR999            RGB light sensor
0x98/0x4C        SA56004ED                Temperature sensor
0x7C/0x3E        SX1509BULTRT            IO Expander


------ [ IO Expander pins ] ------
IO0            Input         Button 1
IO1            Input         Button 2
IO2            Input         Hall switch
IO3            Input         Accelerometer interrupt
IO4            Input         Temperature sensor alert interrupt
IO5            Output         LED Green
IO6            Output         LED Blue
IO7            Output         LED Red
IO8            Output         Potentiometer enable
IO9            Output         RGB light sensor sleep
IO10        Output         Servo ports 1 and 2 power enable
IO11        GPIO         Spare
IO12        GPIO         Spare
IO13        GPIO         Spare
IO14        GPIO         Spare
IO15        GPIO         Spare

*/

const NO_DEVICE = "The device at I2C address 0x%02x is disabled.";


//------------------------------------------------------------------------------
class SX150x {
    //Private variables
    _i2c       = null;
    _addr      = null;
    _callbacks = null;
    _int_pin   = null;

    //Pass in pre-configured I2C since it may be used by other devices
    constructor(i2c, address, int_pin) {
        _i2c  = i2c;
        _addr = address;  //8-bit address
        _callbacks = [];
        _int_pin = int_pin;
    }

    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x", _addr, register));
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register, data) {
        _i2c.write(_addr, format("%c%c", register, data));
        // server.log(format("Setting device 0x%02X register 0x%02X to 0x%02X", _addr, register, data));
    }
    
    function writeBit(register, bitn, level) {
        local value = readReg(register);
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        writeReg(register, value);
    }
    
    function writeMasked(register, data, mask) {
        local value = readReg(register);
        value = (value & ~mask) | (data & mask);
        writeReg(register, value);
    }

    // set or clear a selected GPIO pin, 0-16
    function setPin(gpio, level) {
        writeBit(bank(gpio).REGDATA, gpio % 8, level ? 1 : 0);
    }

    // configure specified GPIO pin as input(0) or output(1)
    function setDir(gpio, output) {
        writeBit(bank(gpio).REGDIR, gpio % 8, output ? 0 : 1);
    }

    // enable or disable input buffers
    function setInputBuffer(gpio, enable) {
        writeBit(bank(gpio).REGINPDIS, gpio % 8, enable ? 0 : 1);
    }

    // enable or disable open drain
    function setOpenDrain(gpio, enable) {
        writeBit(bank(gpio).REGOPENDRN, gpio % 8, enable ? 1 : 0);
    }
    
    // enable or disable internal pull up resistor for specified GPIO
    function setPullUp(gpio, enable) {
        writeBit(bank(gpio).REGPULLUP, gpio % 8, enable ? 1 : 0);
    }
    
    // enable or disable internal pull down resistor for specified GPIO
    function setPullDn(gpio, enable) {
        writeBit(bank(gpio).REGPULLDN, gpio % 8, enable ? 1 : 0);
    }

    // configure whether specified GPIO will trigger an interrupt
    function setIrqMask(gpio, enable) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, enable ? 0 : 1);
    }

    // clear interrupt on specified GPIO
    function clearIrq(gpio) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, 1);
    }

    // get state of specified GPIO
    function getPin(gpio) {
        return ((readReg(bank(gpio).REGDATA) & (1<<(gpio%8))) ? 1 : 0);
    }

    // resets the device with a software reset
    function reboot() {
        writeReg(bank(0).REGRESET, 0x12);
        writeReg(bank(0).REGRESET, 0x34);
    }

    // synchronises the device with a software reset
    function sync() {
        writeBit(bank(0).REGMISC, 2, 1);
        reboot();
        writeBit(bank(0).REGMISC, 2, 0);
    }

    //configure which callback should be called for each pin transition
    function setCallback(gpio, _callback) {
        _callbacks.insert(gpio, _callback);
        
        // Initialize the interrupt Pin
        hardware.pin1.configure(DIGITAL_IN_PULLUP, callback.bindenv(this));
    }

    function callback() {
        local irq = getIrq();
        clearAllIrqs();
        for (local i = 0; i < 16; i++){
            if ( (irq & (1 << i)) && (typeof _callbacks[i] == "function")){
                _callbacks[i](getPin(i)); // Just testing this out for now. It might work ok.
            }
        }
    }
}

//------------------------------------------------------------------------------
class SX1509 extends SX150x {
    
    // I/O Expander internal registers
    static BANK_A = {   REGDATA    = 0x11,
                        REGDIR     = 0x0F,
                        REGPULLUP  = 0x07,
                        REGPULLDN  = 0x09,
                        REGINTMASK = 0x13,
                        REGSNSHI   = 0x16,
                        REGSNSLO   = 0x17,
                        REGINTSRC  = 0x19,
                        REGINPDIS  = 0x01,
                        REGOPENDRN = 0x0B,
                        REGLEDDRV  = 0x21,
                        REGCLOCK   = 0x1E,
                        REGMISC    = 0x1F,
                        REGRESET   = 0x7D}

    static BANK_B = {   REGDATA    = 0x10,
                        REGDIR     = 0x0E,
                        REGPULLUP  = 0x06,
                        REGPULLDN  = 0x08,
                        REGINTMASK = 0x12,
                        REGSNSHI   = 0x14,
                        REGSNSLO   = 0x15,
                        REGINTSRC  = 0x18,
                        REGINPDIS  = 0x00,
                        REGOPENDRN = 0x0A,
                        REGLEDDRV  = 0x20,
                        REGCLOCK   = 0x1E,
                        REGMISC    = 0x1F,
                        REGRESET   = 0x7D}

    constructor(i2c, address, int_pin){
        base.constructor(i2c, address, int_pin);
        _callbacks.resize(16,null);
        reset();
        clearAllIrqs();
    }
    
    //Write registers to default values
    function reset(){
        writeReg(BANK_A.REGDIR, 0xFF);
        writeReg(BANK_A.REGDATA, 0xFF);
        writeReg(BANK_A.REGPULLUP, 0x00);
        writeReg(BANK_A.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_A.REGSNSHI, 0x00);
        writeReg(BANK_A.REGSNSLO, 0x00);
        
        writeReg(BANK_B.REGDIR, 0xFF);
        writeReg(BANK_B.REGDATA, 0xFF);
        writeReg(BANK_B.REGPULLUP, 0x00);
        writeReg(BANK_B.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_B.REGSNSHI, 0x00);
        writeReg(BANK_B.REGSNSLO, 0x00);
    }

    // Returns the register numbers for the bank that the given gpio is on
    function bank(gpio){
        return (gpio > 7) ? BANK_B : BANK_A;
    }

    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges( gpio, rising, falling) {
        local bank = bank(gpio);
        gpio = gpio % 8;
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? bank.REGSNSHI : bank.REGSNSLO, data, mask);
    }

    function clearAllIrqs() {
        writeReg(BANK_A.REGINTSRC,0xff);
        writeReg(BANK_B.REGINTSRC,0xff);
    }

    function getIrq(){
        return ((readReg(BANK_B.REGINTSRC) & 0xFF) << 8) | (readReg(BANK_A.REGINTSRC) & 0xFF);
    }
    
    // sets the clock 
    function setClock(gpio, enable) {
        writeReg(bank(gpio).REGCLOCK, enable ? 0x50 : 0x00); // 2mhz internal oscillator 
    }
    
    // enable or disable the LED drivers
    function setLEDDriver(gpio, enable) {
        writeBit(bank(gpio).REGLEDDRV, gpio & 7, enable ? 1 : 0);
        writeReg(bank(gpio).REGMISC, 0x70); // Set clock to 2mhz / (2 ^ (1-1)) = 2mhz, use linear fading
    }
    
    // sets the Time On value for the LED register
    function setTimeOn(gpio, value) {
        writeReg(gpio<4 ? 0x29+gpio*3 : 0x35+(gpio-4)*5, value)
    }
    
    // sets the On Intensity level LED register
    function setIntensityOn(gpio, value) {
        writeReg(gpio<4 ? 0x2A+gpio*3 : 0x36+(gpio-4)*5, value)
    }
    
    // sets the Time Off value for the LED register
    function setOff(gpio, value) {
        writeReg(gpio<4 ? 0x2B+gpio*3 : 0x37+(gpio-4)*5, value)
    }
    
    // sets the Rise Time value for the LED register
    function setRiseTime(gpio, value) {
        if (gpio % 8 < 4) return; // Can't do all pins
        writeReg(gpio<12 ? 0x38+(gpio-4)*5 : 0x58+(gpio-12)*5, value)
    }
    
    // sets the Fall Time value for the LED register
    function setFallTime(gpio, value) {
        if (gpio % 8 < 4) return; // Can't do all pins
        writeReg(gpio<12 ? 0x39+(gpio-4)*5 : 0x59+(gpio-12)*5, value)
    }
    
}

//------------------------------------------------------------------------------
const LED_OUT = 1000001;
class ExpGPIO {
    _expander = null;  //Instance of an Expander class
    _gpio     = null;  //Pin number of this GPIO pin
    _mode     = null;  //The mode configured for this pin
    
    constructor(expander, gpio) {
        _expander = expander;
        _gpio     = gpio;
    }
    
    //Optional initial state (defaults to 0 just like the imp)
    function configure(mode, param1 = null, param2 = null) {
        _mode = mode;
        
        // set the pin direction and configure the internal pullup resistor, if applicable
        if (mode == DIGITAL_OUT) {
            // Param1 is the initial value of the pin, Param2 is unused.
            _expander.setDir(_gpio,1);
            _expander.setPullUp(_gpio,0);
            if(param1 != null) {
                _expander.setPin(_gpio, param1);    
            } else {
                _expander.setPin(_gpio, 0);
            }
            
            return this;
        } else if (mode == LED_OUT) {
            // Param1 is the initial intensity, Param2 is unused.
            _expander.setPullUp(_gpio, 0);
            _expander.setInputBuffer(_gpio, 0);
            _expander.setOpenDrain(_gpio, 1);
            _expander.setDir(_gpio, 1);
            _expander.setClock(_gpio, 1);
            _expander.setLEDDriver(_gpio, 1);
            _expander.setTimeOn(_gpio, 0);
            _expander.setOff(_gpio, 0);
            _expander.setRiseTime(_gpio, 0);
            _expander.setFallTime(_gpio, 0);
            _expander.setIntensityOn(_gpio, param1 > 0 ? param1 : 0);
            _expander.setPin(_gpio, param1 > 0 ? 0 : 1);
            
            return this;
        } else if (mode == DIGITAL_IN) {
            // Param1 is the callback function
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,0);
        } else if (mode == DIGITAL_IN_PULLUP) {
            // Param1 is the callback function
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,1);
        }
        
        // configure the pin to throw an interrupt, if necessary
        if (typeof param1 == "function") {
            _expander.setIrqMask(_gpio,1);
            _expander.setIrqEdges(_gpio,1,1);
            _expander.setCallback(_gpio, param1);
        } else {
            _expander.setIrqMask(_gpio,0);
            _expander.setIrqEdges(_gpio,0,0);
            _expander.setCallback(_gpio,null);
        }
        
        return this;
    }
    
    function read() { 
        return _expander.getPin(_gpio); 
    }
    
    function write(state) { 
        _expander.setPin(_gpio,state); 
    }
    
    function setIntensity(intensity) { 
        _expander.setIntensityOn(_gpio,intensity); 
    }
    
    function blink(ton, toff, ion, ioff, fade=true) { 
        ton = (ton > 0x1F ? 0x1F : ton);
        toff = (toff > 0x1F ? 0x1F : toff);
        ion = ion & 0xFF;
        ioff = (ioff > 0x07 ? 0x07 : ioff);
        _expander.setTimeOn(_gpio, ton);
        _expander.setOff(_gpio, toff << 3 | ioff);
        _expander.setRiseTime(_gpio, fade?5:0);
        _expander.setFallTime(_gpio, fade?5:0);
        _expander.setIntensityOn(_gpio, ion);
        _expander.setPin(_gpio, ion>0 ? 0 : 1)
    }
    
    function fade(on) {
        _expander.setRiseTime(_gpio, on?5:0);
        _expander.setFallTime(_gpio, on?5:0);
    }
}

//------------------------------------------------------------------------------
class RGBLED {
    
    _expander = null;
    ledR = null;
    ledG = null;
    ledB = null;
    
    constructor(expander, gpioRed, gpioGreen, gpioBlue) {
        _expander = expander;
        ledR = ExpGPIO(_expander, gpioRed).configure(LED_OUT);
        ledG = ExpGPIO(_expander, gpioGreen).configure(LED_OUT);
        ledB = ExpGPIO(_expander, gpioBlue).configure(LED_OUT);
    }
    
    function set(r, g, b, fade=false) {
        ledR.blink(0, 0, r.tointeger(), 0, fade);
        ledG.blink(0, 0, g.tointeger(), 0, fade);
        ledB.blink(0, 0, b.tointeger(), 0, fade);
    }
    
    function blink(r, g, b, fade=true, timeon=1, timeoff=1) {
        // Turn them off and let them sync on their way on
        ledR.write(1); ledG.write(1); ledB.write(1); 
        ledR.blink(timeon.tointeger(), timeoff.tointeger(), r.tointeger(), 0, fade);
        ledG.blink(timeon.tointeger(), timeoff.tointeger(), g.tointeger(), 0, fade);
        ledB.blink(timeon.tointeger(), timeoff.tointeger(), b.tointeger(), 0, fade);
    }
    
}

//------------------------------------------------------------------------------
enum CAP_COLOUR { RED, GREEN, BLUE, CLEAR };
class RGBSensor {

    _i2c  = null;
    _addr = null;
    _expander = null;
    _sleep = null;
    _poll_callback = null;
    _poll_interval = null;
    _poll_timer = null;
    
    // Capacitors - Lower number = higher sensitivity
    static MIN_CAP_COUNT = 0x0; // Min capacitor count
    static MAX_CAP_COUNT = 0xF; // Max capacitor count
    static CAP_ADDRESSES = [0x06, 0x07, 0x08, 0x09];
    
    // Integration slots - Higher number = higher sensitivity
    static MIN_INTEGRATION_SLOTS = 0x000;   // Min integration slots
    static MAX_INTEGRATION_SLOTS = 0xfff;   // Max integration slots
    static INT_ADDRESSES = [0x0a, 0x0c, 0x0e, 0x10];
    
    // RGB reading
    static CTRL_ADDRESS       = 0x00
    static GET_COLOUR_READING = 0x01;
    static COL_LOW_ADDRESSES  = [0x40, 0x42, 0x44, 0x46];
    static COL_HI_ADDRESSES   = [0x41, 0x43, 0x45, 0x47];
         
        
    constructor(i2c, address, expander, gpioSleep, callback) {
        _i2c  = i2c;
        _addr = address;  //8-bit address
        _expander = expander;
        _sleep = ExpGPIO(_expander, gpioSleep).configure(DIGITAL_OUT, 0);
        _poll_callback = callback;
    }
    
    function wake() { 
        _sleep.write(0); 
    }    
    
    function sleep() { 
        _sleep.write(1); 
    }
    
    function initialise(caps = 0x0F, timeslots = 0xFF) {
        wake();
        
        local result1 = _i2c.write(_addr, format("%c%c", CTRL_ADDRESS, 0));
        imp.sleep(0.01);
        local result2 = setRGBCapacitorCounts(caps);
        local result3 = setRGBIntegrationTimeSlots(timeslots);
        
        sleep();
        
        return (result1 == 0) && result2 && result3;
    }
    
    function setRGBCapacitorCounts(count)
    {
        for (local capIndex = CAP_COLOUR.RED; capIndex <= CAP_COLOUR.CLEAR; ++capIndex) {
            local thecount = (typeof count == "array") ? count[capIndex] : count;
            if (!setCapacitorCount(CAP_ADDRESSES[capIndex], thecount)) {
                return false;
            }
        }        
        return true;
    }
    
    function setCapacitorCount(address, count) {
        if (count < MIN_CAP_COUNT) {
            count = MIN_CAP_COUNT;
        } else if (count > MAX_CAP_COUNT) {
            count = MAX_CAP_COUNT;
        }
        
        return _i2c.write(_addr, format("%c%c", address, count)) == 0;
    }
    
    function setRGBIntegrationTimeSlots(value) {
        for (local intIndex = CAP_COLOUR.RED; intIndex <= CAP_COLOUR.CLEAR; ++intIndex) {
            local thevalue = (typeof value == "array") ? value[intIndex] : value;
            if (!setIntegrationTimeSlot(INT_ADDRESSES[intIndex], thevalue & 0xff)) {
                return false;
            }
            if (!setIntegrationTimeSlot(INT_ADDRESSES[intIndex] + 1, thevalue >> 8)) {
                return false;
            }
        }        
        return true;
    }

    function setIntegrationTimeSlot(address, value) {
        
        if (value < MIN_INTEGRATION_SLOTS) {
            value = MIN_INTEGRATION_SLOTS;
        } else if (value > MAX_INTEGRATION_SLOTS) {
            value = MAX_INTEGRATION_SLOTS;
        }
        
        return _i2c.write(_addr, format("%c%c", address, value)) == 0;
    }
    
    function read() { 
        
        local rgbc = [0, 0, 0 ,0];
        wake();
        if (_i2c.write(_addr, format("%c%c", CTRL_ADDRESS, GET_COLOUR_READING)) == 0) {
            // Wait for reading to complete
            local count = 0;
            while (_i2c.read(_addr, format("%c", CTRL_ADDRESS), 1)[0] != 0) {
                count++;
            }
            for (local colIndex = CAP_COLOUR.RED; colIndex <= CAP_COLOUR.CLEAR; ++colIndex) {
                rgbc[colIndex] = _i2c.read(_addr,  format("%c", COL_LOW_ADDRESSES[colIndex]), 1)[0];
            }
            
            for (local colIndex = CAP_COLOUR.RED; colIndex <= CAP_COLOUR.CLEAR; ++colIndex) {
                rgbc[colIndex] += _i2c.read(_addr,  format("%c", COL_HI_ADDRESSES[colIndex]), 1)[0] << 8;
            }
        } else {
            server.error("RGBSensor:GET_COLOUR_READING reading failed.")
        }
        sleep();
        return { r = rgbc[0], g = rgbc[1], b = rgbc[2], c = rgbc[3] };
        
    }
    
    function poll(interval = null, callback = null) {
        if (interval != null && callback != null) {
            _poll_callback = callback;
            _poll_interval = interval;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (_poll_interval == null || _poll_callback == null) {
            server.error("You have to start RGBSensor::poll() with an interval and callback")
        }
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this));
        
        _poll_callback(read())
    }

    function stop() {
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
    }

}

//------------------------------------------------------------------------------
class TempSensor_rev2 {

    _i2c  = null;
    _addr = null;
    _expander = null;
    _poll_callback = null;
    _poll_interval = null;
    _poll_timer = null;
    _alert_lo = null;
    _alert_hi = null;
    _running = false;
    _disabled = false;
    _last_temp = null;
    _last_alert = null;
    
    static REG_LTHB = "\x00"; // Local temp high 
    static REG_LTLB = "\x22";
    static REG_SR   = "\x02";
    static REG_CONR = "\x03";
    static REG_CONW = "\x09";
    static REG_CRR  = "\x04";
    static REG_CRW  = "\x0A";
    static REG_LHSR = "\x05";
    static REG_LHSW = "\x0B";
    static REG_LLSR = "\x06";
    static REG_LLSW = "\x0C";
    static REG_SHOT = "\x0F";
    static REG_LCS  = "\x20";
    static REG_AM   = "\xBF";
    static REG_RMID = "\xFE";
    static REG_RDR  = "\xFF";
    
    
    constructor(i2c, address, expander, gpioAlert) {
        _i2c  = i2c;
        _addr = address;  //8-bit address
        _expander = expander;
        
        local id = _i2c.read(_addr, REG_RMID, 1);
        if (!id || id[0] != 0xA1) {
            server.error(format("The device at I2C address 0x%02x is not a SA5004X temperature sensor.", _addr))
            _disabled = true;
        } else {
            // Clear the config and the status register
            _i2c.write(_addr, REG_CONW + "\xD5"); 
        }
    }
    
    function poll(interval = null, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error("You have to start TempSensor_rev2::poll() with an interval and callback")
            return false;
        }
        
        local temp = get();
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        if (temp != _last_temp) {
            if (_alert_lo == null || _alert_hi == null || ((temp <= _alert_lo && _last_alert != -1) || (temp >= _alert_hi && _last_alert != 1))) {
                _poll_callback(temp);
                _last_alert = (_alert_lo == null) ? null : ((temp <= _alert_lo) ? -1 : 1);
            }
            _last_temp = temp;
        }
    }
    
    function alert(lo, hi, callback = null) {
        // Alert is an alias for poll
        _alert_lo = lo;
        _alert_hi = hi;
        _last_alert = null;
        if (!callback) callback = _poll_callback;
        poll(1, callback);
    }
    
    function stop() {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
        _alert_lo = null;
        _alert_hi = null;
        
        // Power the sensor down
        _i2c.write(_addr, REG_CONW + "\xD5"); 
        _running = false;
    }
    
    function get() {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        
        if (!_running) {
            // Configure a single shot reading
            _i2c.write(_addr, REG_CONW + "\xD5"); 
            
            // Set conversion rate to 1hz
            _i2c.write(_addr, REG_CRW + "\x04"); 
        
            // Ask the sensor to perform a one-shot reading
            _i2c.write(_addr, REG_SHOT + "\x00"); 
        }
        
        // Wait for the sensor to finish the reading
        while ((_i2c.read(_addr, REG_SR, 1)[0] & 0x80) == 0x80);
                    
        // Get 11-bit signed temperature value in 0.125C steps
        local hi = _i2c.read(_addr, REG_LTHB, 1)[0];
        local lo = _i2c.read(_addr, REG_LTLB, 1)[0];
        local temp = (hi << 8) | (lo & 0xFF);
        return int2deg(temp);

    }
    
    function check_alerts() {
        local status = _i2c.read(_addr, REG_SR, 1)[0] & 0x60;
        if (status == 0x20) return -1;
        else if (status == 0x40) return 1;
        else return 0;
    }
    
    
    function deg2sp(temp) {
        local mat = math.abs(temp.tointeger());
        local hi = (temp < 0 ? 0x80 : 0x00) | (mat & 0x7F);
        local lo = ((8.0 * (math.fabs(temp) - mat)).tointeger() << 5) & 0xE0;
        return format("%c%c", hi, lo);
    }
    
    function deg2int(temp) {
        temp = (temp * 8.0).tointeger();
        if (temp < 0) temp = -((~temp & 0x3FF) + 1);
        return (temp << 5) & 0xFFE0;
    }
    
    function int2deg(temp) {
        temp = temp >> 5;
        if (temp & 0x400) temp = -((~temp & 0x3FF) + 1);
        return temp * 0.125;
    }
    
}

//------------------------------------------------------------------------------
class TempSensor_rev3 {

    _i2c  = null;
    _addr = null;
    _expander = null;
    _alert = null;
    _alert_callback = null;
    _poll_callback = null;
    _poll_interval = null;
    _poll_timer = null;
    _last_temp = null;
    _running = false;
    _disabled = false;
    
    static TEMP_REG          = "\x00";
        static CONF_REG          = "\x01";
        static T_LOW_REG         = "\x02";
        static T_HIGH_REG         = "\x03";
        static RESET_VAL          = "\x06"; // Send this value on general-call address (0x00) to reset device
        static DEG_PER_COUNT = 0.0625; // ADC resolution in degrees C
    
    
    constructor(i2c, address, expander, gpioAlert) {
        _i2c  = i2c;
        _addr = address;  //8-bit address
        _expander = expander;
        
        local id = _i2c.read(_addr, TEMP_REG, 1);
        if (id == null) {
            server.error(format("The device at I2C address 0x%02x is not a TMP112 temperature sensor.", _addr))
            _disabled = true;
        } else {
            // Turn the temperature reading off for now
            _alert = ExpGPIO(_expander, gpioAlert).configure(DIGITAL_IN_PULLUP, alert_callback.bindenv(this));
            
            // Shutdown the sensor for now
            local conf = _i2c.read(_addr, CONF_REG, 2);
            _i2c.write(_addr, CONF_REG + format("%c%c", conf[0] | 0x01, conf[1]));
        }
    }
    
    function alert_callback(state) {
        if (_alert_callback && state == 0) _alert_callback(get());
    }
    
    function poll(interval = null, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error("You have to start TempSensor_rev2::poll() with an interval and callback")
            return false;
        }
        
        local temp = get();
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        if (temp != _last_temp) {
            _poll_callback(temp);
            _last_temp = temp;
        }
        
    }
    
    function alert(lo, hi, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        
        callback = callback ? callback : _poll_callback;
        stop();
        _alert_callback = callback;
    
        local tlo = deg2int(lo);
        local thi = deg2int(hi);
        _i2c.write(_addr, T_LOW_REG + format("%c%c", (tlo >> 8) & 0xFF, (tlo & 0xFF)));
        _i2c.write(_addr, T_HIGH_REG + format("%c%c", (thi >> 8) & 0xFF, (thi & 0xFF)));
        _i2c.write(_addr, CONF_REG + "\x62\x80"); // Run continuously

        // Keep track of the fact that we are running continuously
        _running = true;       
    }
    
    function stop() {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
        _alert_callback = null;
        _running = false;
        
        // Power the sensor down
        local conf = _i2c.read(_addr, CONF_REG, 2);
        _i2c.write(_addr, CONF_REG + format("%c%c", conf[0] | 0x01, conf[1]));
        
    }
    
    function get() {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        
        if (!_running) {
            local conf = _i2c.read(_addr, CONF_REG, 2);
                _i2c.write(_addr, CONF_REG + format("%c%c", conf[0] | 0x80, conf[1]));
        
            // Wait for conversion to be finished
            while ((_i2c.read(_addr, CONF_REG, 1)[0] & 0x80) == 0x80);
        }
        
        // Get 12-bit signed temperature value in 0.0625C steps
        local result = _i2c.read(_addr, TEMP_REG, 2);
        local temp = (result[0] << 8) + result[1];
        return int2deg(temp);
    }
    
    function deg2int(temp) {
        temp = (temp * 16.0).tointeger();
        if (temp < 0) temp = -((~temp & 0x7FF) + 1);
        return (temp << 4) & 0xFFF0;
    }
    
    function int2deg(temp) {
        temp = temp >> 4;
        if (temp & 0x800) temp = -((~temp & 0x7FF) + 1);
        return temp * DEG_PER_COUNT;
    }
    
}

//------------------------------------------------------------------------------
class Potentiometer {
    
    _expander = null;
    _gpioEnable = null;
    _pinRead = null;
    _poll_callback = null;
    _poll_interval = 0.2;
    _poll_timer = null;
    _last_pot_value = null;
    _min = 0.0;
    _max = 1.0;
    _integer_only = false;

    constructor(expander, gpioEnable, pinRead) {
        _expander = expander;
        _pinRead = pinRead;
        _pinRead.configure(ANALOG_IN);
        _gpioEnable = ExpGPIO(_expander, gpioEnable).configure(DIGITAL_OUT);
    }
    
    function poll(interval = null, callback = null) {
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error("You have to start TempSensor_rev2::poll() with an interval and callback")
            return false;
        }
        
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        local new_pot_value = get();
        if (_last_pot_value != new_pot_value) {
            _last_pot_value = new_pot_value;
            _poll_callback(new_pot_value);
        }
        
    }

    function stop() {
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
    }

    // Enable or disable the potentiometer
    function setenabled(enable = true) {
        _gpioEnable.write(enable ? 0 : 1);
        if (_checkpot_timer) {
            imp.cancelwakeup(_checkpot_timer);
        }
        if (enable && _callback) {
            _checkpot_timer = imp.wakeup(0, checkpot.bindenv(this));
        }
    }
    
    // Get the enabled status
    function enabled() {
        return _gpioEnable.read() == 0;
    }

    // Sets the minimum and maximum of the output scale 
    function scale(min, max, integer_only = false) {
        _min = min;
        _max = max;
        _integer_only = integer_only;
    }
    
    
    // Gets the current value, rounded to three decimal places
        function get () {
        local f = 0.0 + _min + (_pinRead.read() * (_max - _min) / 65535.0);
                if (_integer_only) return f.tointeger();
        else               return format("%0.03f", f).tofloat();
        }
    
}

//------------------------------------------------------------------------------
class Servo {
    
    _expander = null;
    _gpioEnable = null;
    _pinWrite = null;
    
    constructor(expander, gpioEnable, pinWrite, period=0.02, dutycycle=0.5) {
        _expander = expander;
        _pinWrite = pinWrite;
        _pinWrite.configure(PWM_OUT, period, dutycycle);
        if (gpioEnable != null) {
            _gpioEnable = ExpGPIO(_expander, gpioEnable).configure(DIGITAL_OUT, 1);
        }
    }

    // Enable or disable the potentiometer
    function setenabled(enable = true) {
        if (_gpioEnable) _gpioEnable.write(enable ? 0 : 1);
    }
    
    // Get the enabled status
    function enabled() {
        return _gpioEnable ? (_gpioEnable.read() == 0) : false;
    }
    
    // Read and write the PWM pin
    function read() { return _pinWrite.read() }
    function write(val) { return _pinWrite.write(val) }
    
}

//------------------------------------------------------------------------------
class Accelerometer_rev2 {
    
    _i2c = null;
    _addr = null;
    _expander = null;
    _gpioInterrupt = null;
    _poll_timer = null;
    _poll_interval = null;
    _poll_callback = null;
    _disabled = false;
    
    static CTRL_REG1     = "\x20";
        static CTRL_REG2     = "\x21";
        static CTRL_REG3     = "\x22";
        static DATA_X        = "\x29";
        static DATA_Y        = "\x2B";
        static DATA_Z        = "\x2D";
    static DATA_ALL      = "\xA8";
    static WHO_AM_I      = "\x0F";
    
    constructor(i2c, addr, expander, gpioInterrupt)
    {
        _i2c  = i2c;
        _addr = addr;  //8-bit address
        _expander = expander;
        local id = _i2c.read(_addr, WHO_AM_I, 1);
        if (!id || id[0] != 0x3B) {
            server.error(format("The device at I2C address 0x%02x is not a LIS331DL accelerometer.", _addr))
            _disabled = true;
        } else {
            _gpioInterrupt = ExpGPIO(_expander, gpioInterrupt).configure(DIGITAL_IN, _callbackHandler.bindenv(this));
        }
    }
    
    function _callbackHandler() {
        server.log("Not implemented yet.")
    }
    
    function get() {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        
        local data = _i2c.read(_addr, DATA_ALL, 6);
        local x = 0, y = 0, z = 0;
        if (data != null) {
            x = data[1];
            if (x & 0x80) x = -((~x & 0x7F) + 1);
            x = x / 128.0;
    
            y = data[3];
            if (y & 0x80) y = -((~y & 0x7F) + 1);
            y = y / 128.0;
    
            z = data[5];
            if (z & 0x80) z = -((~z & 0x7F) + 1);
            z = z / 128.0;
        }

        return {x = x, y = y, z = z};
    }
    
    function poll(interval = null, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
                _i2c.write(_addr, CTRL_REG1 + "\xC7");                // Turn on the sensor, enable X, Y, and Z, ODR = 100 Hz
                    _i2c.write(_addr, CTRL_REG2 + "\x00");                // High-pass filter disabled            
        } else if (!_poll_interval || !_poll_callback) {
            server.error("You have to start Accelerometer_rev2::poll() with an interval and callback")
            return false;
        }
        
        local acc = get();
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        _poll_callback(acc.x, acc.y, acc.z);
    }
    
    function alert(callback) {
        // Alert is an alias for poll in this accelerometer
        poll(1, callback);
    }
    
    function stop() {
        if (_disabled) return server.error(format(NO_DEVICE, _addr)); 
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
        _i2c.write(_addr, CTRL_REG1 + "\x00");                // Turn off the sensor
    }
    
}

//------------------------------------------------------------------------------
class Accelerometer_rev3 {
    
    _i2c = null;
    _addr = null;
    _expander = null;
    _gpioInterrupt = null;
    _poll_timer = null;
    _poll_interval = null;
    _poll_callback = null;
    _alert_callback = null;
    _disabled = false;
    _running = false;
    
    static CTRL_REG1     = "\x20";
        static CTRL_REG2     = "\x21";
        static CTRL_REG3     = "\x22";
        static CTRL_REG4     = "\x23";
        static CTRL_REG5     = "\x24";
        static CTRL_REG6     = "\x25";
        static DATA_X_L      = "\x28";
        static DATA_X_H      = "\x29";
        static DATA_Y_L      = "\x2A";
        static DATA_Y_H      = "\x2B";
        static DATA_Z_L      = "\x2C";
        static DATA_Z_H      = "\x2D";
    static DATA_ALL      = "\xA8";
        static INT1_CFG      = "\x30";
        static INT1_SRC      = "\x31";
        static INT1_THS      = "\x32";
        static INT1_DURATION = "\x33";
        static TAP_CFG       = "\x38";
        static TAP_SRC       = "\x39";
        static TAP_THS       = "\x3A";
        static TIME_LIMIT    = "\x3B";
        static TIME_LATENCY  = "\x3C";
        static TIME_WINDOW   = "\x3D";
        static WHO_AM_I      = "\x0F";
    
    constructor(i2c, addr, expander, gpioInterrupt)
    {
        _i2c  = i2c;
        _addr = addr;  //8-bit address
        _expander = expander;
        
        local id = _i2c.read(_addr, WHO_AM_I, 1);
        if (!id || id[0] != 0x33) {
            server.error(format("The device at I2C address 0x%02x is not a LIS3DH accelerometer.", _addr))
            _disabled = true;
        } else {
            _gpioInterrupt = ExpGPIO(_expander, gpioInterrupt).configure(DIGITAL_IN, interruptHandler.bindenv(this));
            _i2c.write(_addr, CTRL_REG1 + "\x00");            // Turn off the sensor
        }
    }
    
    function interruptHandler(state) {
        if (state == 1 && _alert_callback) {
            local acc = get();
            _alert_callback(acc.x, acc.y, acc.z);
        }
    }
    
    function alert(callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        
        _alert_callback = callback;
        _running = true;

            // Setup the accelerometer for sleep-polling
                _i2c.write(_addr, CTRL_REG1 + "\xA7");                // Turn on the sensor, enable X, Y, and Z, ODR = 100 Hz
                _i2c.write(_addr, CTRL_REG2 + "\x00");                // High-pass filter disabled
                _i2c.write(_addr, CTRL_REG3 + "\x40");                // Interrupt driven to INT1 pad
                _i2c.write(_addr, CTRL_REG4 + "\x00");                // FS = 2g
                _i2c.write(_addr, CTRL_REG5 + "\x00");                // Interrupt latched
                _i2c.write(_addr, CTRL_REG6 + "\x00");                  // Interrupt Active High
                _i2c.write(_addr, INT1_THS + "\x10");                        // Set movement threshold = ? mg
                _i2c.write(_addr, INT1_DURATION + "\x00");        // Duration not relevant
                _i2c.write(_addr, INT1_CFG + "\x6A");                        // Configure intertia detection axis/axes - all three. Plus 6D.
                _i2c.read(_addr, INT1_SRC, 1);                          // Clear any interrupts

    }
    
    function poll(interval = null, callback = null) {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error("You have to start Accelerometer_rev3::poll() with an interval and callback")
            return false;
        }
        
        local acc = get();
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        _poll_callback(acc.x, acc.y, acc.z);
    }
    
    function stop() {
        if (_disabled) return server.error(format(NO_DEVICE, _addr)); 
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
        _alert_callback = null;
        _running = false;
        _i2c.write(_addr, CTRL_REG1 + "\x00");                // Turn off the sensor
    }
    
    function get() {
        if (_disabled) return server.error(format(NO_DEVICE, _addr));

        // Configure settings of the accelerometer
        if (!_running) {
                        _i2c.write(_addr, CTRL_REG1 + "\x47");  // Turn on the sensor, enable X, Y, and Z, ODR = 50 Hz
                        _i2c.write(_addr, CTRL_REG2 + "\x00");  // High-pass filter disabled
                        _i2c.write(_addr, CTRL_REG3 + "\x40");  // Interrupt driven to INT1 pad
                        _i2c.write(_addr, CTRL_REG4 + "\x00");  // FS = 2g
                        _i2c.write(_addr, CTRL_REG5 + "\x00");  // Interrupt Not latched
                        _i2c.write(_addr, CTRL_REG6 + "\x00");  // Interrupt Active High (not actually used)
                        _i2c.read(_addr, INT1_SRC, 1);          // Clear any interrupts
                }
        
        local data = _i2c.read(_addr, DATA_ALL, 6);
        local x = 0, y = 0, z = 0;
        if (data != null) {
            x = (data[1] << 8 | data[0]);
            if (x & 0x8000) x = -((~x & 0x7FFF) + 1);
            x = x / 32767.0;
            
            y = (data[3] << 8 | data[2]);
            if (y & 0x8000) y = -((~y & 0x7FFF) + 1);
            y = y / 32767.0;
            
            z = (data[5] << 8 | data[4]);
            if (z & 0x8000) z = -((~z & 0x7FFF) + 1);
            z = z / 32767.0;
            
            return {x = x, y = y, z = z};
        }

    }
    
    
    
}

//------------------------------------------------------------------------------
class Hannah {
    
    i2c = null;
    ioexp = null;
    pot = null;
    btn1 = null;
    btn2 = null;
    hall = null;
    srv1 = null;
    srv2 = null;
    acc = null;
    led = null;
    light = null;
    temp = null;
    
    on_pot_changed = null;
    on_btn1_changed = null;
    on_btn2_changed = null;
    on_hall_changed = null;
    on_acc_changed = null;
    on_light_changed = null;
    on_temp_changed = null;
    
    constructor() {
        
        // Initialize the I2C bus
        i2c = hardware.i2c89;
        i2c.configure(CLOCK_SPEED_400_KHZ);
        
        // Initialize IO expander
        ioexp = SX1509(i2c, 0x7C, hardware.pin1);
        
        // Potentiometer on pin 2 and enabled on IO pin 8
        pot = Potentiometer(ioexp, 8, hardware.pin2);
        pot.poll(0.1, call_callback("on_pot_changed"));
        
        // Button 1 on IO pin 0
        btn1 = ExpGPIO(ioexp, 0).configure(DIGITAL_IN_PULLUP, call_callback("on_btn1_changed"));
        
        // Button 2 on IO pin 1
        btn2 = ExpGPIO(ioexp, 1).configure(DIGITAL_IN_PULLUP, call_callback("on_btn2_changed"));
        
        // Hall switch on IO pin 2
        hall = ExpGPIO(ioexp, 2).configure(DIGITAL_IN_PULLUP, call_callback("on_hall_changed"));
        
        // Accelerometer
        acc = Accelerometer_rev2(i2c, 0x38, ioexp, 3);
        if (acc._disabled) acc = Accelerometer_rev3(i2c, 0x30, ioexp, 3);
        acc.alert(call_callback("on_acc_changed"));
        
        // RGB Light Sensor on i2c port 0xE8/0x74 with the sleep pin on IO pin 9
        light = RGBSensor(i2c, 0xE8, ioexp, 9, call_callback("on_light_changed"));
        light.poll(1, call_callback("on_light_changed"));

        // Temperature Sensor on i2c port 0x98/0x4C with the alert pin on IO pin 4
        temp = TempSensor_rev2(i2c, 0x98, ioexp, 4);
        if (temp._disabled) temp = TempSensor_rev3(i2c, 0x92, ioexp, 4);
        temp.poll(1, call_callback("on_temp_changed"));

        // Servo1 on pin5
        srv1 = Servo(ioexp, 10, hardware.pin5);
        
        // Servo2 on pin7
        srv2 = Servo(ioexp, 10, hardware.pin7);
        
        // RGB LED on IO pins 7 (red), 5 (green) and 6 (blue)
        led = RGBLED(ioexp, 7, 5, 6);
    }
    
    
    function call_callback(callback_name) {
        return function(a=null, b=null, c=null) {
            if ((callback_name in this) && (typeof this[callback_name] == "function")) {
                if (a == null) {
                    this[callback_name]();
                } else if (b == null) {
                    this[callback_name](a);
                } else if (c == null) {
                    this[callback_name](a, b);
                } else {
                    this[callback_name](a, b, c);
                }
            }
        }.bindenv(this)
    }
}


//==============================================================================
// Everything below here is sample application code.
//
hannah <- Hannah();

// read temperature and send to agent
device.send("temp", { temp = hannah.temp.get() });
    
// disconnect from wifi and enter deep sleep for 15 minutes
imp.onidle(function() { server.sleepfor(900.0); }); // 15 minutes
