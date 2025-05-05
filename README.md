## <img width="64" alt="Quiet You! icon" src="https://github.com/user-attachments/assets/dae7a276-ae64-4fb4-ae74-48bc3efcedde" /> Quiet You!

This is a straight forward macOS app that automatically closes any notification that you want. It exists purely because there are a bunch of notifications in macOS that you can't turn off. (Those incessant "Background Items Added" notifications are the reason I made this app in the first place.)

You configure it by providing a list of text strings, and any time a notification pops on screen, the app will check to see if any bit of text in the notification contains any one of the text strings you added to the app. If there's a match, it will close the notification immediately.

Unfortunately there's no good way to stop the notification from appearing at all, but this way it's at least only on screen for a split second.

This app requires macOS 13 or later. It also requires Accessibility permissions in order to function. It should prompt for that when you first enable the app.


### How it works (the technical details)

It uses the Accessibility API and observers to be notified of when new UI elements appear in the Notification Center's list of notifications. It then finds all the labels in the notification and checks to see if they contain matching text, and upon finding a match sends the annoyingly hard to click X button on the notification a "press" message. This should be equivalent of actually clicking the X button but without needing to generate any actual mouse clicks. And since there's no polling it should have a very low CPU, memory and energy impact.


#### Possible future work:

Figuring out how to inject code into the Notification Center to actually prevent unwanted notifications from ever opening in the first place, for those sufficiently brave, desperate, or foolish. (I'm at least two of the three.)