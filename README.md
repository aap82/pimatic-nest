
pimatic-nest
===================

Nest Plugin for <a href="https://pimatic.org">Pimatic</a> using old version of Firebase.


Nest Token
===================
You need to obtain a nest api token for authentication using firebase.  If you have on already, continue on to `Setup`

First start by signing up for a Nest developer account. Then sign in.
    
Click on `CREATE NEW PRODUCT`

Fill out the top section, and under `Users` select `Individual`.

In the Permissions Section, click on the following:

    Away
    Structure
    Thermostat
    
**Make sure you select `read/write` radio.**  

Also, feel free to add items if you have them (I do not).
    
If everything went well, you should now be directed to a screen that provides the following info:
    
    Product ID
    Product Secret
    Authorization URL
    
Then click copy the Authorization URL and in a separate browser, navigate to it.  It will ask for you sign in, and if all is successful, you should see a screen that says: `Use this pincode to connect to Nest`
     
Now, with the Product ID, Product Secret and PinCode, you can obtain a token by executing the following in a terminal:
     
     curl -X POST \
       -d "code=PIN_CODE&client_id=PRODUCT_ID&client_secret=PRODUCT_SECRET&grant_type=authorization_code" \
       "https://api.home.nest.com/oauth2/access_token"
     
    
Replacing the PIN_CODE, PRODUCT_ID, and PRODUCT_SECRET with your own.
    
After executing, you should get a response like:
    
    {
        "access_token":"YOUR-NEST-API-TOKEN",
        "expires_in":315360000
    }
    

No you can use the `"access_token"` below.


Installation & Setup
====================
first stop pimatic with either:

    sudo service pimatic stop
or

    sudo systemctl stop pimatic.service
    
From the root of your pimatic app installation folder
    
    cd node_modules
    git clone https://github.com/aap82/pimatic-nest.git
    cd pimatic-nest
    npm install
    
    
edit the pimatic `config.json` file, adding an entry in the `plugins` section like so:
 
    {
        "plugin": "nest",
        "token": "YOUR-NEST-API-TOKEN"     
    }



Restart pimatic, and head over to the `DEVICES` section of the front-end app, and click on `DISCOVER DEVICES`

Devices
====================
After clicking on discover, you should see the three types of devices provided by this plugin:
 **NestThermostat**, **NestHomeAwayPresence.**, and **NestHomeAwayToggle**

NestThermostat
----------------

_It is required that you <a href="https://nest.com/support/article/How-can-I-lock-Nest-so-that-it-can-only-be-adjusted-within-a-certain-temperature-range">LOCK</a>
any Nest Thermostat you wish to control via pimatic._

The NestThermostat device has one configuration option:  **show_temp_scale**, which will add either F or C
to the unit property of any temperature attributes.  There is a temp_scale config option, but this will
be auto-populated on discovery.  

Using the **Temperature Lock** feature of the Nest thermostat allows for changing the hvac_mode of the thermostat through the api, 
as well as providing sane boundaries of allowable temperatures.

See the **devices/nest-thermostat-attributes.coffee** to see all device attributes.
Aside from Nest specific attributes, the device provides attributes for ambient_temperature and
humidity provided by the thermostat.

Only one attribute is not directly linked to the Nest API: **is_blocked**.  Nest limits
the number and frequency of calls to the API.  If a request is blocked, subsequent requests
for that thermostat will be blocked for 15 minutes.  It only takes a 5-6 calls within a
few minutes to trigger a BLOCKED error. 

The device has no predicate providers. However, you can use the **attribute of a device**
predicate provider to react to changes in ambient_temperature and humidity.

The device provides a number of actions than can be called via the REST api. 
See the **devices/nest-thermostat-actions.coffee** to see available actions.

There are also two action providers for this device, that allow to decrement, increment or set the
target_temperature of a thermostat.  Another allows for the changing of the hvac_mode. 

There is no device available for the mobile-front-end, however, with action providers coupled
with a ButtonsDevice would allow controlling a thermostat from the gui.


NestHomeAwayPresence
--------------

This is the **Home/Away** status of your nest location (also known as a structure), and is
and extension of the native pimatic PresenceDevice, so the **device is present/absent**
predicate provider can be used.

              
NestHomeAwayToggle
--------------

This device allows the user to toggle the Home/Away state using the mobile-front-end.
However, NestHomeAwayToggle is not an extension of the SwitchActuator device, therefore,
none of the switch device predicate or action providers or action providers.

This device has one predicate provider: **nest home/away**, which is triggered
when the device changes to that state.

There are no action providers.  The only way to change the Home/Away state is via the mobile-front-end,
and confirmation of the action is forced.

_For a particular location, only one of the NestHomeAwayPresence or NestHomeAwayToggle is allowed.
You cannot create both devices for one location._
                                                                                                                          








