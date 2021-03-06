## Guidance

This is ios repositorie for NeuralRecon, futher user guidance please refer to https://github.com/Burningdust21/NeuralRecon/blob/webcam/WEBCAM.md

## Installation

1. Clone the project, open with Xcode 12.

2. Wait a while for Xcode to load swift packages, it should be looking like this:

   <img src="images/SPM.png" alt="SPM" style="zoom:50%;" />

   If it fails, you can retry by reset package cahches:

   <img src="images/pkg_reset.png" alt="pkg_reset" style="zoom:25%;" />

3. Insert your developer certification into the following targets:

   - NeuralRecon

     ![sign_neural](images/sign_neural.png)

   - ScreenCast

     ![sign_screenCast](images/sign_screenCast.png)
     
     **Note: remember to select your `Team`, and change `Bundle Identifier`(such as add a suffix)!**

4. Install it to you iPhone/iPad

   Select scheme `NeuralRecon`
   
   <img src="images/run.png" alt="run" style="zoom: 33%;" />
   
   
   
   Then select your device(Not simulators)
   
   <img src="images/device.png" alt="device" style="zoom:33%;" />
   
   Hit the "play" button, you good to go!
   
   On first launch, it will ask you for camera and network permission, click `OK`!
   
   <img src="images/permission.PNG" alt="permission" style="zoom: 25%;" />

## UI introduction 

1. Recording interface

   <img src="images/recording.png" alt="recording" style="zoom: 25%;" />

   ① Switch to Preference interface

   ② Switch to Preference interface

   ③ Actual publishing video frames resolution after encoding

   ④ Video frames capturing resolution

   ⑤ Start/end recording button

   ⑥ Publishing frame rate. If it is 0, it means that something is wrong, check your networks, or use lower sending resolution.

2. Preperence interface

   ![preference](images/preference.png)① Switch to Recording interface

   ② Switch to Preference interface

   ③ RTMP server address

   ④ Stream name 

   ⑤ Select the video frame resolution supported by the device. Shown in brackets are the number of different resolutions supported by the device for video recording. N options available means that there are N resolutions to choose from, corresponding to serial numbers [0, N-1]. After changing, press Enter to confirm, and you can view the selected resolution in ④ on the Recording interface.

   ⑥ The ratio of video frame size compression during encoding. Decrease the original resolution by the scale factor, and get the actual resolution as ③ of the Recording interface. If the scale factor is too small, that is, the resolution after encoding is closer to the original resolution, transmission errors may occur.

   ⑦ The encoding bitrate field. The actual bitrate is mutiplied by 1500

   

**NOTE:  press enter after keyboard input to commit changes in test boxes** 

- Make sure sender and receiver are connected to the server.

