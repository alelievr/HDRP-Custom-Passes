using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Video;

[RequireComponent(typeof(VideoPlayer))]
[RequireComponent(typeof(Animation))]
public class SyncVideoAndAnim : MonoBehaviour
{
    VideoPlayer videoPlayer;
    new Animation animation;

    bool firstUpdate = true;
    
    // Start is called before the first frame update
    void Start()
    {
        videoPlayer = GetComponent<VideoPlayer>();
        animation = GetComponent<Animation>();

        animation.Play();

        videoPlayer.Play();
        videoPlayer.loopPointReached += Loop;
    }

    // Force a sync of the animation at the first rendered frame
    void Update()
    {
        if (firstUpdate)
        {
            var t = (float) videoPlayer.time;
            
            foreach (AnimationState state in animation)
            {
                state.time = t;
            }
            
            firstUpdate = false;
        }
    }

    // Force a sync of the animation each time the video player loops
    void Loop(VideoPlayer vp)
    {
        foreach (AnimationState state in animation)
        {
            state.time = 0;
        }
    }
}
