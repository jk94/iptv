package com.jk94.iptv_player

import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper

// Extends the simple_pip_mode wrapper so Picture-in-Picture callbacks
// (onPipEntered/onPipExited) are forwarded to Flutter.
class MainActivity : PipCallbackHelperActivityWrapper()
