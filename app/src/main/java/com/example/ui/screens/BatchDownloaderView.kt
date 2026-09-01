package com.example.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Audiotrack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.example.data.model.BatchDownloadItem
import com.example.data.model.BatchItemStatus
import com.example.data.model.MediaFormat
import com.example.data.model.MediaQuality
import com.example.data.model.MediaType
import com.example.ui.viewmodel.MediaVaultViewModel
import java.util.Locale

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun BatchDownloaderView(
    viewModel: MediaVaultViewModel,
    onNavigateToLibrary: () -> Unit
) {
    val batchInputText by viewModel.batchInputText.collectAsStateWithLifecycle()
    val batchItems by viewModel.batchItems.collectAsStateWithLifecycle()
    val isBatchParsing by viewModel.isBatchParsing.collectAsStateWithLifecycle()
    val isBatchDownloading by viewModel.isBatchDownloading.collectAsStateWithLifecycle()

    val selectedCount = remember(batchItems) { batchItems.count { it.isSelected } }
    val completedCount = remember(batchItems) { batchItems.count { it.status == BatchItemStatus.COMPLETED } }
    val allSelected = remember(batchItems, selectedCount) { batchItems.isNotEmpty() && selectedCount == batchItems.size }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .testTag("batch_downloader_view"),
        contentPadding = PaddingValues(bottom = 96.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Multi-link Input Card
        item {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("batch_input_card"),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(18.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Surface(
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.primaryContainer,
                                modifier = Modifier.size(36.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        Icons.Default.LibraryMusic,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onPrimaryContainer,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text(
                                    text = "Batch Media Input",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = "Paste multiple YouTube/web links (one per line)",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        if (batchInputText.isNotEmpty()) {
                            IconButton(
                                onClick = { viewModel.setBatchInputText("") },
                                modifier = Modifier.testTag("btn_clear_batch_input")
                            ) {
                                Icon(Icons.Default.Clear, contentDescription = "Clear", tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    OutlinedTextField(
                        value = batchInputText,
                        onValueChange = { viewModel.setBatchInputText(it) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(130.dp)
                            .testTag("input_batch_urls"),
                        placeholder = {
                            Text(
                                "https://youtube.com/watch?v=...\nhttps://youtu.be/...\nhttps://youtube.com/shorts/...",
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                                style = MaterialTheme.typography.bodySmall
                            )
                        },
                        shape = RoundedCornerShape(14.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = MaterialTheme.colorScheme.primary,
                            unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
                            focusedContainerColor = MaterialTheme.colorScheme.surface,
                            unfocusedContainerColor = MaterialTheme.colorScheme.surface
                        )
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { viewModel.pasteBatchFromClipboard() },
                            shape = RoundedCornerShape(12.dp),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                            modifier = Modifier
                                .weight(1f)
                                .testTag("btn_paste_batch_clipboard")
                        ) {
                            Icon(Icons.Default.ContentPaste, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Paste Clipboard", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium)
                        }

                        Button(
                            onClick = { viewModel.parseBatchUrls() },
                            enabled = batchInputText.isNotBlank() && !isBatchParsing,
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary,
                                contentColor = MaterialTheme.colorScheme.onPrimary
                            ),
                            modifier = Modifier
                                .weight(1f)
                                .testTag("btn_parse_batch_links")
                        ) {
                            if (isBatchParsing) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(16.dp),
                                    strokeWidth = 2.dp,
                                    color = MaterialTheme.colorScheme.onPrimary
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Parsing...", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium)
                            } else {
                                Icon(Icons.Default.AutoAwesome, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Parse Links", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium)
                            }
                        }
                    }

                    // Sample Quick-Loader
                    if (batchItems.isEmpty()) {
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.Center
                        ) {
                            TextButton(
                                onClick = {
                                    val sampleText = viewModel.sampleLinks.joinToString("\n") { it.url }
                                    viewModel.setBatchInputText(sampleText)
                                    viewModel.parseBatchUrls(sampleText)
                                },
                                modifier = Modifier.testTag("btn_load_sample_batch")
                            ) {
                                Icon(Icons.Default.Link, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Load 4 Sample URLs for Quick Testing", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                            }
                        }
                    }
                }
            }
        }

        // Batch Items Toolbar & Controls
        if (batchItems.isNotEmpty()) {
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("batch_toolbar_card"),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp)
                    ) {
                        // Summary & Selection row
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.clickable { viewModel.selectAllBatchItems(!allSelected) }
                            ) {
                                Checkbox(
                                    checked = allSelected,
                                    onCheckedChange = { viewModel.selectAllBatchItems(it) },
                                    colors = CheckboxDefaults.colors(
                                        checkedColor = MaterialTheme.colorScheme.primary,
                                        checkmarkColor = MaterialTheme.colorScheme.onPrimary
                                    )
                                )
                                Text(
                                    text = "Select All (${selectedCount}/${batchItems.size})",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }

                            Row {
                                if (completedCount > 0) {
                                    TextButton(onClick = { viewModel.clearCompletedBatchItems() }) {
                                        Text("Clear Done ($completedCount)", style = MaterialTheme.typography.labelSmall, color = Color(0xFF4CAF50))
                                    }
                                }
                                TextButton(onClick = { viewModel.clearBatchList() }) {
                                    Text("Clear All", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        // Quick Format Apply All Chips
                        Text(
                            text = "Apply Format to All Selected:",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(6.dp))

                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            FilterChip(
                                selected = false,
                                onClick = { viewModel.applyBatchFormatToAll(MediaFormat.MP4, MediaQuality.BEST) },
                                label = { Text("All MP4 (1080p)", style = MaterialTheme.typography.labelSmall) },
                                leadingIcon = { Icon(Icons.Default.Videocam, contentDescription = null, modifier = Modifier.size(14.dp)) },
                                colors = FilterChipDefaults.filterChipColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
                            )
                            FilterChip(
                                selected = false,
                                onClick = { viewModel.applyBatchFormatToAll(MediaFormat.MP3, MediaQuality.AUDIO_ONLY) },
                                label = { Text("All MP3 (320k)", style = MaterialTheme.typography.labelSmall) },
                                leadingIcon = { Icon(Icons.Default.Audiotrack, contentDescription = null, modifier = Modifier.size(14.dp)) },
                                colors = FilterChipDefaults.filterChipColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
                            )
                            FilterChip(
                                selected = false,
                                onClick = { viewModel.applyBatchFormatToAll(MediaFormat.M4A, MediaQuality.AUDIO_COMPACT) },
                                label = { Text("All M4A (AAC)", style = MaterialTheme.typography.labelSmall) },
                                leadingIcon = { Icon(Icons.Default.Audiotrack, contentDescription = null, modifier = Modifier.size(14.dp)) },
                                colors = FilterChipDefaults.filterChipColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
                            )
                        }

                        Spacer(modifier = Modifier.height(14.dp))

                        // Start Concurrent Downloads Button
                        Button(
                            onClick = { viewModel.startBatchDownloads() },
                            enabled = selectedCount > 0,
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("btn_start_batch_downloads"),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary,
                                contentColor = MaterialTheme.colorScheme.onPrimary
                            )
                        ) {
                            Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Download $selectedCount Selected Items",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }

            // List of Individual Batch Items
            items(batchItems, key = { it.id }) { item ->
                BatchItemCard(
                    item = item,
                    onToggleSelect = { viewModel.toggleBatchItemSelection(item.id) },
                    onFormatChange = { format -> viewModel.setBatchItemFormat(item.id, format) },
                    onQualityChange = { quality -> viewModel.setBatchItemQuality(item.id, quality) },
                    onPause = { viewModel.pauseBatchItem(item.id) },
                    onResume = { viewModel.resumeBatchItem(item.id) },
                    onRetry = { viewModel.retryBatchItem(item.id) },
                    onRemove = { viewModel.removeBatchItem(item.id) }
                )
            }
        }
    }
}

@Composable
fun BatchItemCard(
    item: BatchDownloadItem,
    onToggleSelect: () -> Unit,
    onFormatChange: (MediaFormat) -> Unit,
    onQualityChange: (MediaQuality) -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onRetry: () -> Unit,
    onRemove: () -> Unit
) {
    val context = LocalContext.current
    val media = item.mediaInfo

    val statusColor = when (item.status) {
        BatchItemStatus.COMPLETED -> Color(0xFF4CAF50)
        BatchItemStatus.DOWNLOADING -> MaterialTheme.colorScheme.primary
        BatchItemStatus.QUEUED -> MaterialTheme.colorScheme.tertiary
        BatchItemStatus.FAILED -> MaterialTheme.colorScheme.error
        BatchItemStatus.PAUSED, BatchItemStatus.INTERRUPTED -> Color(0xFFFFB74D)
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    val statusLabel = when (item.status) {
        BatchItemStatus.IDLE, BatchItemStatus.READY -> "Ready"
        BatchItemStatus.PARSING -> "Parsing"
        BatchItemStatus.QUEUED -> "Queued"
        BatchItemStatus.DOWNLOADING -> "Downloading"
        BatchItemStatus.COMPLETED -> "Saved"
        BatchItemStatus.FAILED -> "Failed"
        BatchItemStatus.PAUSED -> "Paused"
        BatchItemStatus.INTERRUPTED -> "Interrupted"
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("batch_item_card_${item.id}"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (item.isSelected) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        ),
        border = BorderStroke(
            1.dp,
            if (item.status == BatchItemStatus.DOWNLOADING) MaterialTheme.colorScheme.primary
            else if (item.isSelected) MaterialTheme.colorScheme.outline
            else MaterialTheme.colorScheme.outlineVariant
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp)
        ) {
            // Top Row: Checkbox, Thumbnail, Title, and Status Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Checkbox(
                    checked = item.isSelected,
                    onCheckedChange = { onToggleSelect() },
                    colors = CheckboxDefaults.colors(
                        checkedColor = MaterialTheme.colorScheme.primary,
                        checkmarkColor = MaterialTheme.colorScheme.onPrimary
                    ),
                    modifier = Modifier.size(24.dp)
                )

                Spacer(modifier = Modifier.width(10.dp))

                // Thumbnail
                Box(
                    modifier = Modifier
                        .size(52.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.Center
                ) {
                    if (media != null && media.thumbnailUrl.isNotEmpty()) {
                        AsyncImage(
                            model = ImageRequest.Builder(context)
                                .data(media.thumbnailUrl)
                                .crossfade(true)
                                .build(),
                            contentDescription = media.title,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Icon(
                            if (item.format.mediaType == MediaType.VIDEO) Icons.Default.Videocam else Icons.Default.Audiotrack,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(26.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = media?.title ?: item.rawUrl,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = media?.author ?: "Web Link",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Spacer(modifier = Modifier.width(6.dp))

                // Status Pill
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = statusColor.copy(alpha = 0.15f),
                    border = BorderStroke(1.dp, statusColor.copy(alpha = 0.5f))
                ) {
                    Text(
                        text = statusLabel,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = statusColor,
                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.dp)
                    )
                }

                IconButton(
                    onClick = onRemove,
                    modifier = Modifier
                        .size(28.dp)
                        .testTag("btn_remove_batch_${item.id}")
                ) {
                    Icon(Icons.Default.Clear, contentDescription = "Remove", tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f), modifier = Modifier.size(16.dp))
                }
            }

            // Format & Quality Controls (if not completed or actively downloading)
            if (item.status == BatchItemStatus.READY || item.status == BatchItemStatus.IDLE) {
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    FilterChip(
                        selected = item.format == MediaFormat.MP4,
                        onClick = { onFormatChange(MediaFormat.MP4) },
                        label = { Text("MP4 Video", style = MaterialTheme.typography.labelSmall) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MaterialTheme.colorScheme.primary,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                        )
                    )
                    FilterChip(
                        selected = item.format == MediaFormat.MP3,
                        onClick = { onFormatChange(MediaFormat.MP3) },
                        label = { Text("MP3 Audio", style = MaterialTheme.typography.labelSmall) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MaterialTheme.colorScheme.primary,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                        )
                    )
                    FilterChip(
                        selected = item.format == MediaFormat.M4A,
                        onClick = { onFormatChange(MediaFormat.M4A) },
                        label = { Text("M4A Audio", style = MaterialTheme.typography.labelSmall) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MaterialTheme.colorScheme.primary,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                        )
                    )
                }
            }

            // Progress Bar and Speed Metrics (when downloading, queued, paused, or interrupted)
            if (item.status == BatchItemStatus.DOWNLOADING || item.status == BatchItemStatus.QUEUED ||
                item.status == BatchItemStatus.PAUSED || item.status == BatchItemStatus.INTERRUPTED) {
                Spacer(modifier = Modifier.height(10.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (item.status == BatchItemStatus.QUEUED) "Waiting in queue..."
                        else "${formatBytes(item.bytesDownloaded)} / ${formatBytes(item.totalBytes)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        if (item.speedFormatted.isNotEmpty()) {
                            Text(
                                text = item.speedFormatted,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Text(
                            text = "${(item.progress * 100).toInt()}%",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                LinearProgressIndicator(
                    progress = { item.progress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp)),
                    color = if (item.status == BatchItemStatus.PAUSED || item.status == BatchItemStatus.INTERRUPTED) Color(0xFFFFB74D) else MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant,
                    strokeCap = StrokeCap.Round
                )
            }

            // Error message if failed
            if (item.status == BatchItemStatus.FAILED && !item.errorMessage.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = MaterialTheme.colorScheme.errorContainer,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "Error: ${item.errorMessage}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            // Action Buttons for this item
            if (item.status == BatchItemStatus.DOWNLOADING || item.status == BatchItemStatus.PAUSED ||
                item.status == BatchItemStatus.INTERRUPTED || item.status == BatchItemStatus.FAILED) {
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (item.status == BatchItemStatus.DOWNLOADING) {
                        OutlinedButton(
                            onClick = onPause,
                            shape = RoundedCornerShape(8.dp),
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                        ) {
                            Icon(Icons.Default.Pause, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Pause", style = MaterialTheme.typography.labelSmall)
                        }
                    } else if (item.status == BatchItemStatus.PAUSED || item.status == BatchItemStatus.INTERRUPTED) {
                        Button(
                            onClick = onResume,
                            shape = RoundedCornerShape(8.dp),
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary,
                                contentColor = MaterialTheme.colorScheme.onPrimary
                            )
                        ) {
                            Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Resume", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                        }
                    } else if (item.status == BatchItemStatus.FAILED) {
                        Button(
                            onClick = onRetry,
                            shape = RoundedCornerShape(8.dp),
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary,
                                contentColor = MaterialTheme.colorScheme.onPrimary
                            )
                        ) {
                            Icon(Icons.Default.Replay, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Retry", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

private fun formatBytes(bytes: Long): String {
    return when {
        bytes >= 1024 * 1024 * 1024 -> String.format(Locale.US, "%.1f GB", bytes.toDouble() / (1024 * 1024 * 1024))
        bytes >= 1024 * 1024 -> String.format(Locale.US, "%.1f MB", bytes.toDouble() / (1024 * 1024))
        bytes >= 1024 -> String.format(Locale.US, "%.0f KB", bytes.toDouble() / 1024)
        else -> "$bytes B"
    }
}
