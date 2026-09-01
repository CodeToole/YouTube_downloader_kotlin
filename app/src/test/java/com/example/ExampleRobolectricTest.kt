package com.example

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.extractor.MediaExtractor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class ExampleRobolectricTest {

  @Test
  fun `read string from context`() {
    val context = ApplicationProvider.getApplicationContext<Context>()
    val appName = context.getString(R.string.app_name)
    assertEquals("Media Vault", appName)
  }

  @Test
  fun `test youtube url parsing`() {
    val watchUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    val shortsUrl = "https://youtube.com/shorts/kJQP7kiw5Fk?si=123"
    val shortLink = "https://youtu.be/dQw4w9WgXcQ"

    assertEquals("dQw4w9WgXcQ", MediaExtractor.extractYouTubeId(watchUrl))
    assertEquals("kJQP7kiw5Fk", MediaExtractor.extractYouTubeId(shortsUrl))
    assertEquals("dQw4w9WgXcQ", MediaExtractor.extractYouTubeId(shortLink))
    assertTrue(MediaExtractor.isSupportedUrl(watchUrl))
  }
}
