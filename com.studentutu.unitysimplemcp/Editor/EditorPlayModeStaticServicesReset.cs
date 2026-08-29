using System;
using UnityEditor;
using UnityEngine;

namespace SimpleUnityMCP.Editor
{
    [InitializeOnLoad]
    public static class EditorPlayModeStaticServicesReset
    {
        static EditorPlayModeStaticServicesReset()
        {
            EditorApplication.playModeStateChanged -= OnPlayModeStateChanged;
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
        }

        private static void OnPlayModeStateChanged(PlayModeStateChange state)
        {
            if (state != PlayModeStateChange.ExitingPlayMode)
                return;

            try
            {
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
        }
    }
}