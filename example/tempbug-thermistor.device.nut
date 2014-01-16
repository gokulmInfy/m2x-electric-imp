// all calculations are done in Kelvin
// these are constants for a particular thermistor:
//    - http://www.digikey.com/product-search/en?vendor=0&keywords=495-2143-ND
// if using a different thermistor, check your datasheet for the proper values

const b_therm = 3988;
const t0_therm = 298.15;
const r_therm = 100000;

class Thermistor {

	// thermistor constants
	// see comments at start of file
	b_therm = null;
	t0_therm = null;
	r0_therm = null;

	// configuration options
	points_per_read = null;
	high_side_therm = null;

	// analog input pin
	p_therm = null;

	constructor(pin, b, t0, r, points = 10, _high_side_therm = true) {
		this.p_therm = pin;
		this.p_therm.configure(ANALOG_IN);

		// force all of these values to floats in case they come in as integers
		this.b_therm = b * 1.0;
		this.t0_therm = t0 * 1.0;
		this.r0_therm = r * 1.0;
		this.points_per_read = points * 1.0;

		this.high_side_therm = _high_side_therm;
	}

	// read thermistor in Kelvin
	function read() {
		local vdda_raw = 0;
		local vtherm_raw = 0;
		for (local i = 0; i < points_per_read; i++) {
			vdda_raw += hardware.voltage();
			vtherm_raw += p_therm.read();
		}
		local vdda = (vdda_raw / points_per_read);
		local v_therm = (vtherm_raw / points_per_read) * (vdda / 65535.0);

		local r_therm = 0;        
		if (high_side_therm) {
			r_therm = (vdda - v_therm) * (r0_therm / v_therm);
		} else {
			r_therm = r0_therm / ((vdda / v_therm) - 1);
		}

		local ln_therm = math.log(r0_therm / r_therm);
		local t_therm = (t0_therm * b_therm) / (b_therm - t0_therm * ln_therm);
		return t_therm;
	}

	// read thermistor in Celsius
	function read_c() {
		return this.read() - 273.15;
	}

	// read thermistor in Fahrenheit
	function read_f() {
		local temp = this.read() - 273.15;
		return (temp * 9.0 / 5.0 + 32.0);
	}
}

function round(x, y) {
    return (x.tofloat()/y+(x>0?0.5:-0.5)).tointeger()*y
}

// Setup Thermistor Enable Pin
NTC_Read_Enable_L <- hardware.pin8;
NTC_Read_Enable_L.configure(DIGITAL_OUT_OD);
NTC_Read_Enable_L.write(1);

// Instantiate the thermistor class
thermistor <- Thermistor(hardware.pin9, b_therm, t0_therm, r_therm, 10, true);

// enable thermistor
NTC_Read_Enable_L.write(0); imp.sleep(0.01);

// read temperature and send to agent
agent.send("temp", { temp = round(thermistor.read_c(), 0.5) });

// disable thermistor
NTC_Read_Enable_L.write(1);

// disconnect from wifi and enter deep sleep for 15 minutes
imp.onidle(function() { server.sleepfor(900.0); }); // 15 minutes