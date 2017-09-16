
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
You should see the two types of devices provided by this plugin **NestThermostat** and **NestPresence.**

Thermostat
----------------

_It is required that you <a href="https://nest.com/support/article/How-can-I-lock-Nest-so-that-it-can-only-be-adjusted-within-a-certain-temperature-range">LOCK</a> any Nest Thermostat you wish to control via pimatic._



Presence
--------------

This is the **Home/Away** status of your nest location (also known as a structure).








