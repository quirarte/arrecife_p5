String cfgArduinoCom;
int cfgArduinoBaud;
int cfgDefaultCamIndex;
int cfgEsperaPostMs;
int[] cfgSpeciesFoodColors;
boolean[] cfgSpeciesFoodColorSet;
float cfgFoodColorToneRange;
String[] cfgFondoFiles;
SpeciesProfile[] cfgSpeciesProfiles;

String normalizeHexColor(String raw) {
  if (raw == null) return "";

  String s = trim(raw);
  if (s.length() == 0) return "";

  if (s.startsWith("#")) s = s.substring(1);
  if (s.startsWith("0x") || s.startsWith("0X")) s = s.substring(2);

  return s;
}

boolean isValidHexColor(String raw) {
  String s = normalizeHexColor(raw);

  if (s.length() != 6 && s.length() != 8) return false;

  for (int i = 0; i < s.length(); i++) {
    char ch = s.charAt(i);
    boolean isDigit = (ch >= '0' && ch <= '9');
    boolean isLowerHex = (ch >= 'a' && ch <= 'f');
    boolean isUpperHex = (ch >= 'A' && ch <= 'F');
    if (!isDigit && !isLowerHex && !isUpperHex) return false;
  }

  return true;
}

int parseHexColor(String raw) {
  String s = normalizeHexColor(raw);

  if (s.length() == 6) {
    return (0xFF << 24) | unhex(s);
  }

  if (s.length() == 8) {
    return unhex(s);
  }

  return 0;
}

void loadRuntimeConfig() {
  cfgArduinoCom = "";
  cfgArduinoBaud = 9600;
  cfgDefaultCamIndex = 0;
  cfgEsperaPostMs = 1600;
  cfgFoodColorToneRange = 0.20;
  cfgSpeciesFoodColors = new int[0];
  cfgSpeciesFoodColorSet = new boolean[0];
  cfgFondoFiles = new String[0];
  cfgSpeciesProfiles = new SpeciesProfile[0];

  JSONObject runtimeCfg = loadJSONObject("app_config.json");
  if (runtimeCfg == null) {
    println("app_config.json no existe, usando configuracion minima por defecto");
    return;
  }

  cfgArduinoCom = runtimeCfg.getString("arduino_com", cfgArduinoCom);
  cfgArduinoBaud = runtimeCfg.getInt("arduino_baud", cfgArduinoBaud);
  cfgDefaultCamIndex = runtimeCfg.getInt("default_cam_index", cfgDefaultCamIndex);
  cfgEsperaPostMs = runtimeCfg.getInt("espera_post_ms", cfgEsperaPostMs);
  cfgFoodColorToneRange = runtimeCfg.getFloat("food_color_tone_range", cfgFoodColorToneRange);
  cfgFoodColorToneRange = constrain(cfgFoodColorToneRange, 0.0, 1.0);

  JSONArray foodColors = runtimeCfg.getJSONArray("food_colors");
  if (foodColors == null || foodColors.size() == 0) {
    println("ERROR: app_config.json requiere 'food_colors' como array no vacio.");
    return;
  }

  cfgSpeciesFoodColors = new int[foodColors.size()];
  cfgSpeciesFoodColorSet = new boolean[foodColors.size()];
  int validFoodColors = 0;

  for (int i = 0; i < foodColors.size(); i++) {
    String colorRaw = foodColors.getString(i, "");
    if (colorRaw == null || trim(colorRaw).length() == 0) {
      println("WARNING: food_colors[" + i + "] vacio. Se ignora.");
      continue;
    }

    if (isValidHexColor(colorRaw)) {
      cfgSpeciesFoodColors[i] = parseHexColor(colorRaw);
      cfgSpeciesFoodColorSet[i] = true;
      validFoodColors++;
    } else {
      println("WARNING: formato invalido para food_colors[" + i + "]='" + colorRaw + "'. Usa #RRGGBB o #AARRGGBB");
    }
  }

  if (validFoodColors == 0) {
    println("ERROR: no hay colores validos en 'food_colors'.");
    return;
  }

  JSONArray fondoFiles = runtimeCfg.getJSONArray("fondo_files");
  if (fondoFiles != null && fondoFiles.size() > 0) {
    String[] parsedFondos = new String[fondoFiles.size()];
    int validFondos = 0;
    for (int i = 0; i < fondoFiles.size(); i++) {
      String raw = fondoFiles.getString(i, "");
      if (raw == null || trim(raw).length() == 0) continue;
      parsedFondos[validFondos++] = trim(raw);
    }
    if (validFondos > 0) {
      cfgFondoFiles = new String[validFondos];
      for (int i = 0; i < validFondos; i++) cfgFondoFiles[i] = parsedFondos[i];
    }
  }

  JSONArray speciesProfiles = runtimeCfg.getJSONArray("species_profiles");
  if (speciesProfiles != null && speciesProfiles.size() > 0) {
    SpeciesProfile[] parsedSpecies = new SpeciesProfile[speciesProfiles.size()];
    int validSpecies = 0;

    for (int i = 0; i < speciesProfiles.size(); i++) {
      JSONObject o = speciesProfiles.getJSONObject(i);
      if (o == null) continue;

      String s1 = o.getString("sound1", "");
      String s2 = o.getString("sound2", "");
      if (s1 == null || s2 == null) continue;
      s1 = trim(s1);
      s2 = trim(s2);
      if (s1.length() == 0 || s2.length() == 0) continue;

      int defaultFiducialId = i + 1;
      int fiducialId = o.getInt("fiducial_id", defaultFiducialId);
      boolean hasUpperFiducialLimit = (CFG.FIDUCIAL_ID_MAX >= CFG.FIDUCIAL_ID_MIN);
      boolean fiducialOutOfRange = (fiducialId < CFG.FIDUCIAL_ID_MIN)
        || (hasUpperFiducialLimit && fiducialId > CFG.FIDUCIAL_ID_MAX);
      if (fiducialOutOfRange) {
        String fidRangeMsg = hasUpperFiducialLimit
          ? (CFG.FIDUCIAL_ID_MIN + ".." + CFG.FIDUCIAL_ID_MAX)
          : ("minimo " + CFG.FIDUCIAL_ID_MIN);
        println("WARNING: fiducial_id fuera de rango para species_profiles[" + i + "]: " + fiducialId
          + ". Rango valido: " + fidRangeMsg + ". Se ignora perfil.");
        continue;
      }

      boolean duplicateFiducial = false;
      for (int j = 0; j < validSpecies; j++) {
        if (parsedSpecies[j] != null && parsedSpecies[j].fiducialId == fiducialId) {
          duplicateFiducial = true;
          break;
        }
      }
      if (duplicateFiducial) {
        println("WARNING: fiducial_id duplicado en species_profiles[" + i + "]: " + fiducialId + ". Se ignora perfil duplicado.");
        continue;
      }

      int foodId = -1;
      if (!o.isNull("food_index")) {
        foodId = o.getInt("food_index", -1);
      } else if (!o.isNull("food")) {
        int legacyFoodNumber = o.getInt("food", -1);
        // Compatibilidad legacy: "food" historico era base-1.
        foodId = legacyFoodNumber - 1;
        println("WARNING: species_profiles[" + i + "] usa 'food' (legacy base-1). "
          + "Migra a 'food_index' base-0. Valor recibido=" + legacyFoodNumber
          + " -> food_index=" + foodId);
      }

      if (foodId < 0 || foodId >= cfgSpeciesFoodColors.length || !cfgSpeciesFoodColorSet[foodId]) {
        int fallbackFoodId = -1;
        if (cfgSpeciesFoodColors.length > 0 && cfgSpeciesFoodColorSet[0]) {
          fallbackFoodId = 0;
        } else {
          for (int k = 0; k < cfgSpeciesFoodColorSet.length; k++) {
            if (cfgSpeciesFoodColorSet[k]) {
              fallbackFoodId = k;
              break;
            }
          }
        }

        if (fallbackFoodId < 0) {
          println("WARNING: food_index fuera de rango o sin color valido en species_profiles[" + i + "]: " + foodId
            + ". No hay comida valida configurada en food_colors. Se ignora perfil.");
          continue;
        }

        println("WARNING: food_index fuera de rango o sin color valido en species_profiles[" + i + "]: " + foodId
          + ". Se usara la primera comida disponible food_index=" + fallbackFoodId + ".");
        foodId = fallbackFoodId;
      }

      parsedSpecies[validSpecies++] = new SpeciesProfile(fiducialId, s1, s2, foodId);
    }

    if (validSpecies > 0) {
      cfgSpeciesProfiles = new SpeciesProfile[validSpecies];
      for (int i = 0; i < validSpecies; i++) {
        cfgSpeciesProfiles[i] = parsedSpecies[i];
      }
    }
  }

  println("Config runtime: arduino_com=" + cfgArduinoCom
    + " arduino_baud=" + cfgArduinoBaud
    + " default_cam_index=" + cfgDefaultCamIndex
    + " espera_post_ms=" + cfgEsperaPostMs
    + " food_color_tone_range=" + nf(cfgFoodColorToneRange, 1, 3)
    + " food_colors=" + cfgSpeciesFoodColors.length
    + " species_profiles=" + ((cfgSpeciesProfiles == null) ? 0 : cfgSpeciesProfiles.length)
    + " fondo_files=" + ((cfgFondoFiles == null) ? 0 : cfgFondoFiles.length));
}
