import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF141414); // cards, tiles
  static const elevated = Color(0xFF1F1F1F); // bottom sheets, modals
  static const divider = Color(0xFF2A2A2A); // subtle separators
  static const progressIndicators = Color(0xFF3E3E3E); // progress bars, sliders

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF); // artists, metadata

  static const accentFallback = Color.fromARGB(255, 208, 69, 226);
}

abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const listTitle = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
  );
  static const listSubtitle = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );
  static const playerTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const playerSubtitle = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
}

enum AlbumArtSize { track, playlist, album, full }

abstract final class AppSizes {
  static const int trackAlbumArt = 48;
  static const int playlistAlbumArt = 64;
  static int albumAlbumArt = 512;
  static int fullAlbumArt = 2024;

  static int getSize(AlbumArtSize size) {
    switch (size) {
      case AlbumArtSize.track:
        return trackAlbumArt;
      case AlbumArtSize.playlist:
        return playlistAlbumArt;
      case AlbumArtSize.album:
        return albumAlbumArt;
      case AlbumArtSize.full:
        return fullAlbumArt;
    }
  }

  static double getSizeD(AlbumArtSize size) {
    return getSize(size).toDouble();
  }
}
