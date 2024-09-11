# frozen_string_literal: true

def start_log_timer( name = nil )
  @log_timer = Time.now
  @log_timer_name = name || caller( 2 ).first.split( "/" ).last
  Rails.logger.debug "\n\n[DEBUG] *********** Started log timer from #{@log_timer_name} at #{@log_timer} ***********"
end

def end_log_timer
  Rails.logger.debug "[DEBUG] *********** Finished log timer from " \
    "#{@log_timer_name} (#{Time.now - @log_timer}s) ***********\n\n"
  @log_timer = nil
  @log_timer_name = nil
end
alias stop_log_timer end_log_timer

def log_timer( name = nil )
  start_log_timer( name )
  r = yield
  end_log_timer
  r
end

class Object
  def try_methods( *methods )
    methods.each do | method |
      if respond_to?( method ) && !send( method ).blank?
        return send( method )
      end
    end
    nil
  end
end

# Call a proc or lambda that returns something array-like, but if doing so
# raises an exception, use the block to partition the args into smaller chunks
# of work in the form of arrays of arrays of args to call the callable with.
# This method recursively calls itself, breaking the work down into smaller and
# smaller chunks until it can do the work without raising the specified
# exceptions. This is intended to be used with burly elasticsearch queries that
# will raise exceptions when the result set is too large. options takes an
# optional exception_checker that is yet another callable to check whether the
# exception should trigger partitioning. If that returns false, the exception
# will be raised.
def call_and_rescue_with_partitioner( callable, args, exceptions, options = {}, &partitioner )
  exceptions = [exceptions].flatten
  options[:depth] ||= 0
  debug = options[:debug]
  args = [args].flatten
  begin
    callable.call( *args )
  rescue *exceptions => e
    if options[:exception_checker] && !options[:exception_checker].call( e )
      raise e
    end

    arg_partitions = partitioner.call( args )
    # If parallel operation was requested, we want to limit the amount of
    # parallel workers so they don't scale out infinitely. If you request 4
    # parallel workers with a binary partitioner, then the max depth for
    # parallelization should be 2 (first recursion should generate 2 workers,
    # next should generate a total of 4). Beyond that we should run subsequent
    # recursions in sequence. This will save a bit of time regardless, but will
    # work best when the partitions are relatively even. For the kinds of
    # imbalanced data we generally work with, the heavier partitions will end
    # up running in sequence in a single worker. Kind of wish we could do this
    # with promises instead...
    max_parallel_depth = ( options[:parallel].to_f / arg_partitions.size ).floor
    puts "max_parallel_depth: #{max_parallel_depth}" if debug
    puts "options[:depth]: #{options[:depth]}" if debug
    if options[:parallel] && options[:depth].to_i < max_parallel_depth
      puts "processing partitions in parallel for args: #{args}" if debug
      Parallel.map( arg_partitions, in_threads: arg_partitions.size ) do | partitioned_args |
        call_and_rescue_with_partitioner(
          callable,
          partitioned_args,
          exceptions,
          options.merge( depth: options[:depth] + 1 ),
          &partitioner
        )
      end.flatten
    else
      puts "processing partitions in sequence for args: #{args}" if debug
      arg_partitions.map do | partitioned_args |
        call_and_rescue_with_partitioner(
          callable,
          partitioned_args,
          exceptions,
          options.merge( depth: options[:depth] + 1 ),
          &partitioner
        )
      end.flatten
    end
  end
end

def ratatosk( options = {} )
  src = options[:src]
  site = options[:site] || Site.default
  providers = site&.ratatosk_name_providers || ["col"]
  if providers.blank?
    Ratatosk
  elsif providers.include?( src.to_s.downcase )
    Ratatosk::Ratatosk.new( name_providers: [src] )
  else
    Ratatosk::Ratatosk.new( name_providers: providers )
  end
end

class String
  def sanitize_encoding
    begin
      blank?
    rescue ArgumentError => e
      raise e unless e.message =~ /invalid byte sequence in UTF-8/

      return encode( "utf-8", "iso-8859-1" )
    end
    self
  end

  # rubocop:disable Naming/PredicateName
  def is_ja?
    !!( self =~ /[ぁ-ゖァ-ヺー一-龯々]/ )
  end
  # rubocop:enable Naming/PredicateName

  def mentioned_users
    logins = scan( /(\B)@([\\\w][\\\w\-_]*)/ ).flatten.filter {| l | !l.blank? }
    return [] if logins.blank?

    User.where( login: logins ).limit( 500 )
  end

  def context_of_pattern( pattern, context_length = 100 )
    fix = ".{0,#{context_length}}"
    return unless ( matches = match( /(#{fix})(#{pattern})(#{fix})/ ) )

    parts = []
    parts << "..." if matches[1].length == context_length
    parts << matches[1]
    parts << matches[2]
    parts << matches[3]
    parts << "..." if matches[3].length == context_length
    parts.join
  end

  # https://stackoverflow.com/a/19438403
  LATO_CODEPOINTS = [
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
    51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69,
    70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88,
    89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105,
    106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120,
    121, 122, 123, 124, 125, 126, 128, 129, 130, 131, 132, 133, 134, 135, 136,
    137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151,
    152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166,
    167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181,
    182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196,
    197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211,
    212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226,
    227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241,
    242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256,
    257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271,
    272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286,
    287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301,
    302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316,
    317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331,
    332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346,
    347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360, 361,
    362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376,
    377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391,
    392, 393, 394, 395, 396, 397, 398, 399, 400, 401, 402, 403, 404, 405, 406,
    407, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 419, 420, 421,
    422, 423, 424, 425, 426, 427, 428, 429, 430, 431, 432, 433, 434, 435, 436,
    437, 438, 439, 440, 441, 442, 443, 444, 445, 446, 447, 448, 449, 450, 451,
    452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 466,
    467, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477, 478, 479, 480, 481,
    482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496,
    497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 511,
    512, 513, 514, 515, 516, 517, 518, 519, 520, 521, 522, 523, 524, 525, 526,
    527, 528, 529, 530, 531, 532, 533, 534, 535, 536, 537, 538, 539, 540, 541,
    542, 543, 544, 545, 546, 547, 548, 549, 550, 551, 552, 553, 554, 555, 556,
    557, 558, 559, 560, 561, 562, 563, 564, 565, 566, 567, 568, 569, 570, 571,
    572, 573, 574, 575, 576, 577, 578, 579, 580, 581, 582, 583, 584, 585, 586,
    587, 588, 589, 590, 591, 592, 593, 594, 595, 596, 597, 598, 599, 600, 601,
    602, 603, 604, 605, 606, 607, 608, 609, 610, 611, 612, 613, 614, 615, 616,
    617, 618, 619, 620, 621, 622, 623, 624, 625, 626, 627, 628, 629, 630, 631,
    632, 633, 634, 635, 636, 637, 638, 639, 640, 641, 642, 643, 644, 645, 646,
    647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657, 658, 659, 660, 661,
    662, 663, 664, 665, 666, 667, 668, 669, 670, 671, 672, 673, 674, 675, 676,
    677, 678, 679, 680, 681, 682, 683, 684, 685, 686, 687, 688, 689, 690, 691,
    692, 693, 694, 695, 696, 697, 698, 699, 700, 701, 702, 703, 704, 705, 706,
    707, 708, 709, 710, 711, 712, 713, 714, 715, 716, 717, 718, 719, 720, 721,
    722, 723, 724, 725, 726, 727, 728, 729, 730, 731, 732, 733, 734, 735, 736,
    737, 738, 739, 740, 741, 742, 743, 744, 745, 746, 747, 748, 749, 750, 751,
    752, 753, 754, 755, 756, 757, 758, 759, 760, 761, 762, 763, 764, 765, 766,
    767, 768, 769, 770, 771, 772, 773, 774, 775, 776, 777, 778, 779, 780, 781,
    782, 783, 784, 785, 786, 787, 788, 789, 790, 791, 792, 793, 794, 795, 796,
    797, 798, 799, 800, 801, 802, 803, 804, 805, 806, 807, 808, 809, 810, 811,
    812, 813, 814, 815, 816, 817, 818, 819, 820, 821, 822, 823, 824, 825, 826,
    827, 828, 829, 830, 831, 832, 833, 834, 835, 836, 837, 838, 839, 840, 841,
    842, 843, 844, 845, 846, 847, 848, 849, 850, 851, 852, 853, 854, 855, 856,
    857, 858, 859, 860, 861, 862, 863, 864, 865, 866, 867, 868, 869, 870, 871,
    872, 873, 874, 875, 876, 877, 878, 879, 884, 885, 890, 891, 892, 893, 894,
    900, 901, 902, 903, 904, 905, 906, 908, 910, 911, 912, 913, 914, 915, 916,
    917, 918, 919, 920, 921, 922, 923, 924, 925, 926, 927, 928, 929, 931, 932,
    933, 934, 935, 936, 937, 938, 939, 940, 941, 942, 943, 944, 945, 946, 947,
    948, 949, 950, 951, 952, 953, 954, 955, 956, 957, 958, 959, 960, 961, 962,
    963, 964, 965, 966, 967, 968, 969, 970, 971, 972, 973, 974, 976, 977, 978,
    979, 980, 981, 982, 983, 984, 985, 986, 987, 988, 989, 990, 991, 992, 993,
    994, 995, 996, 997, 998, 999, 1000, 1001, 1002, 1003, 1004, 1005, 1006,
    1007, 1008, 1009, 1010, 1011, 1012, 1013, 1014, 1015, 1016, 1017, 1018,
    1019, 1020, 1021, 1022, 1023, 1024, 1025, 1026, 1027, 1028, 1029, 1030,
    1031, 1032, 1033, 1034, 1035, 1036, 1037, 1038, 1039, 1040, 1041, 1042,
    1043, 1044, 1045, 1046, 1047, 1048, 1049, 1050, 1051, 1052, 1053, 1054,
    1055, 1056, 1057, 1058, 1059, 1060, 1061, 1062, 1063, 1064, 1065, 1066,
    1067, 1068, 1069, 1070, 1071, 1072, 1073, 1074, 1075, 1076, 1077, 1078,
    1079, 1080, 1081, 1082, 1083, 1084, 1085, 1086, 1087, 1088, 1089, 1090,
    1091, 1092, 1093, 1094, 1095, 1096, 1097, 1098, 1099, 1100, 1101, 1102,
    1103, 1104, 1105, 1106, 1107, 1108, 1109, 1110, 1111, 1112, 1113, 1114,
    1115, 1116, 1117, 1118, 1119, 1120, 1121, 1122, 1123, 1124, 1125, 1126,
    1127, 1128, 1129, 1130, 1131, 1132, 1133, 1134, 1135, 1136, 1137, 1138,
    1139, 1140, 1141, 1142, 1143, 1144, 1145, 1146, 1147, 1148, 1149, 1150,
    1151, 1152, 1153, 1154, 1155, 1156, 1157, 1158, 1160, 1161, 1162, 1163,
    1164, 1165, 1166, 1167, 1168, 1169, 1170, 1171, 1172, 1173, 1174, 1175,
    1176, 1177, 1178, 1179, 1180, 1181, 1182, 1183, 1184, 1185, 1186, 1187,
    1188, 1189, 1190, 1191, 1192, 1193, 1194, 1195, 1196, 1197, 1198, 1199,
    1200, 1201, 1202, 1203, 1204, 1205, 1206, 1207, 1208, 1209, 1210, 1211,
    1212, 1213, 1214, 1215, 1216, 1217, 1218, 1219, 1220, 1221, 1222, 1223,
    1224, 1225, 1226, 1227, 1228, 1229, 1230, 1231, 1232, 1233, 1234, 1235,
    1236, 1237, 1238, 1239, 1240, 1241, 1242, 1243, 1244, 1245, 1246, 1247,
    1248, 1249, 1250, 1251, 1252, 1253, 1254, 1255, 1256, 1257, 1258, 1259,
    1260, 1261, 1262, 1263, 1264, 1265, 1266, 1267, 1268, 1269, 1270, 1271,
    1272, 1273, 1274, 1275, 1276, 1277, 1278, 1279, 1280, 1281, 1282, 1283,
    1284, 1285, 1286, 1287, 1288, 1289, 1290, 1291, 1292, 1293, 1294, 1295,
    1296, 1297, 1298, 1299, 3647, 7424, 7425, 7426, 7427, 7428, 7429, 7430,
    7431, 7432, 7433, 7434, 7435, 7436, 7437, 7438, 7439, 7440, 7441, 7442,
    7443, 7444, 7445, 7446, 7447, 7448, 7449, 7450, 7451, 7452, 7453, 7454,
    7455, 7456, 7457, 7458, 7459, 7460, 7461, 7462, 7463, 7464, 7465, 7466,
    7467, 7468, 7469, 7470, 7471, 7472, 7473, 7474, 7475, 7476, 7477, 7478,
    7479, 7480, 7481, 7482, 7483, 7484, 7485, 7486, 7487, 7488, 7489, 7490,
    7491, 7492, 7493, 7494, 7495, 7496, 7497, 7498, 7499, 7500, 7501, 7502,
    7503, 7504, 7505, 7506, 7507, 7508, 7509, 7510, 7511, 7512, 7513, 7514,
    7515, 7516, 7517, 7518, 7519, 7520, 7521, 7522, 7523, 7524, 7525, 7526,
    7527, 7528, 7529, 7530, 7531, 7532, 7533, 7534, 7535, 7536, 7537, 7538,
    7539, 7540, 7541, 7542, 7543, 7544, 7545, 7546, 7547, 7548, 7549, 7550,
    7551, 7552, 7553, 7554, 7555, 7556, 7557, 7558, 7559, 7560, 7561, 7562,
    7563, 7564, 7565, 7566, 7567, 7568, 7569, 7570, 7571, 7572, 7573, 7574,
    7575, 7576, 7577, 7578, 7579, 7580, 7581, 7582, 7583, 7584, 7585, 7586,
    7587, 7588, 7589, 7590, 7591, 7592, 7593, 7594, 7595, 7596, 7597, 7598,
    7599, 7600, 7601, 7602, 7603, 7604, 7605, 7606, 7607, 7608, 7609, 7610,
    7611, 7612, 7613, 7614, 7615, 7616, 7617, 7618, 7619, 7620, 7621, 7622,
    7623, 7624, 7625, 7626, 7678, 7679, 7680, 7681, 7682, 7683, 7684, 7685,
    7686, 7687, 7688, 7689, 7690, 7691, 7692, 7693, 7694, 7695, 7696, 7697,
    7698, 7699, 7700, 7701, 7702, 7703, 7704, 7705, 7706, 7707, 7708, 7709,
    7710, 7711, 7712, 7713, 7714, 7715, 7716, 7717, 7718, 7719, 7720, 7721,
    7722, 7723, 7724, 7725, 7726, 7727, 7728, 7729, 7730, 7731, 7732, 7733,
    7734, 7735, 7736, 7737, 7738, 7739, 7740, 7741, 7742, 7743, 7744, 7745,
    7746, 7747, 7748, 7749, 7750, 7751, 7752, 7753, 7754, 7755, 7756, 7757,
    7758, 7759, 7760, 7761, 7762, 7763, 7764, 7765, 7766, 7767, 7768, 7769,
    7770, 7771, 7772, 7773, 7774, 7775, 7776, 7777, 7778, 7779, 7780, 7781,
    7782, 7783, 7784, 7785, 7786, 7787, 7788, 7789, 7790, 7791, 7792, 7793,
    7794, 7795, 7796, 7797, 7798, 7799, 7800, 7801, 7802, 7803, 7804, 7805,
    7806, 7807, 7808, 7809, 7810, 7811, 7812, 7813, 7814, 7815, 7816, 7817,
    7818, 7819, 7820, 7821, 7822, 7823, 7824, 7825, 7826, 7827, 7828, 7829,
    7830, 7831, 7832, 7833, 7834, 7835, 7838, 7840, 7841, 7842, 7843, 7844,
    7845, 7846, 7847, 7848, 7849, 7850, 7851, 7852, 7853, 7854, 7855, 7856,
    7857, 7858, 7859, 7860, 7861, 7862, 7863, 7864, 7865, 7866, 7867, 7868,
    7869, 7870, 7871, 7872, 7873, 7874, 7875, 7876, 7877, 7878, 7879, 7880,
    7881, 7882, 7883, 7884, 7885, 7886, 7887, 7888, 7889, 7890, 7891, 7892,
    7893, 7894, 7895, 7896, 7897, 7898, 7899, 7900, 7901, 7902, 7903, 7904,
    7905, 7906, 7907, 7908, 7909, 7910, 7911, 7912, 7913, 7914, 7915, 7916,
    7917, 7918, 7919, 7920, 7921, 7922, 7923, 7924, 7925, 7926, 7927, 7928,
    7929, 7936, 7937, 7938, 7939, 7940, 7941, 7942, 7943, 7944, 7945, 7946,
    7947, 7948, 7949, 7950, 7951, 7952, 7953, 7954, 7955, 7956, 7957, 7960,
    7961, 7962, 7963, 7964, 7965, 7968, 7969, 7970, 7971, 7972, 7973, 7974,
    7975, 7976, 7977, 7978, 7979, 7980, 7981, 7982, 7983, 7984, 7985, 7986,
    7987, 7988, 7989, 7990, 7991, 7992, 7993, 7994, 7995, 7996, 7997, 7998,
    7999, 8000, 8001, 8002, 8003, 8004, 8005, 8008, 8009, 8010, 8011, 8012,
    8013, 8016, 8017, 8018, 8019, 8020, 8021, 8022, 8023, 8025, 8027, 8029,
    8031, 8032, 8033, 8034, 8035, 8036, 8037, 8038, 8039, 8040, 8041, 8042,
    8043, 8044, 8045, 8046, 8047, 8048, 8049, 8050, 8051, 8052, 8053, 8054,
    8055, 8056, 8057, 8058, 8059, 8060, 8061, 8064, 8065, 8066, 8067, 8068,
    8069, 8070, 8071, 8072, 8073, 8074, 8075, 8076, 8077, 8078, 8079, 8080,
    8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8089, 8090, 8091, 8092,
    8093, 8094, 8095, 8096, 8097, 8098, 8099, 8100, 8101, 8102, 8103, 8104,
    8105, 8106, 8107, 8108, 8109, 8110, 8111, 8112, 8113, 8114, 8115, 8116,
    8118, 8119, 8120, 8121, 8122, 8123, 8124, 8125, 8126, 8127, 8128, 8129,
    8130, 8131, 8132, 8134, 8135, 8136, 8137, 8138, 8139, 8140, 8141, 8142,
    8143, 8144, 8145, 8146, 8147, 8150, 8151, 8152, 8153, 8154, 8155, 8157,
    8158, 8159, 8160, 8161, 8162, 8163, 8164, 8165, 8166, 8167, 8168, 8169,
    8170, 8171, 8172, 8173, 8174, 8175, 8178, 8179, 8180, 8182, 8183, 8184,
    8185, 8186, 8187, 8188, 8189, 8190, 8192, 8193, 8194, 8195, 8196, 8197,
    8198, 8199, 8200, 8201, 8202, 8203, 8204, 8205, 8206, 8207, 8208, 8210,
    8211, 8212, 8213, 8214, 8215, 8216, 8217, 8218, 8219, 8220, 8221, 8222,
    8223, 8224, 8225, 8226, 8230, 8239, 8240, 8242, 8243, 8244, 8249, 8250,
    8252, 8253, 8254, 8260, 8286, 8287, 8304, 8305, 8308, 8309, 8310, 8311,
    8312, 8313, 8314, 8315, 8316, 8317, 8318, 8319, 8320, 8321, 8322, 8323,
    8324, 8325, 8326, 8327, 8328, 8329, 8330, 8331, 8332, 8333, 8334, 8335,
    8336, 8337, 8338, 8339, 8340, 8352, 8353, 8354, 8355, 8356, 8357, 8358,
    8359, 8360, 8361, 8362, 8363, 8364, 8365, 8366, 8367, 8368, 8369, 8370,
    8371, 8372, 8373, 8376, 8377, 8378, 8413, 8453, 8467, 8470, 8471, 8480,
    8482, 8486, 8494, 8498, 8525, 8526, 8531, 8532, 8533, 8534, 8535, 8536,
    8537, 8538, 8539, 8540, 8541, 8542, 8543, 8579, 8580, 8592, 8593, 8594,
    8595, 8596, 8597, 8598, 8599, 8600, 8601, 8616, 8706, 8719, 8721, 8722,
    8725, 8729, 8730, 8734, 8735, 8745, 8747, 8776, 8800, 8801, 8804, 8805,
    8962, 8976, 8992, 8993, 9312, 9313, 9314, 9315, 9316, 9317, 9318, 9319,
    9320, 9321, 9322, 9323, 9324, 9325, 9326, 9327, 9328, 9329, 9330, 9331,
    9450, 9451, 9452, 9453, 9454, 9455, 9456, 9457, 9458, 9459, 9460, 9471,
    9472, 9474, 9484, 9488, 9492, 9496, 9633, 9642, 9643, 9674, 9675, 9676,
    9679, 9702, 9728, 9788, 9833, 10_102, 10_103, 10_104, 10_105, 10_106,
    10_107, 10_108, 10_109, 10_110, 10_111, 11_360, 11_361, 11_362, 11_363,
    11_364, 11_365, 11_366, 11_367, 11_368, 11_369, 11_370, 11_371, 11_372,
    11_380, 11_381, 11_382, 11_383, 11_799, 12_775, 42_776, 42_777, 42_778,
    42_784, 42_785, 63_743, 64_256, 64_257, 64_258, 64_259, 64_260, 65_056,
    65_057, 65_058, 65_059, 65_279
  ].freeze

  def lato_support?
    chars.detect {| c | !LATO_CODEPOINTS.include?( c.codepoints[0] ) }.blank?
  end

  def all_latin_chars?
    chars.detect {| c | c.bytes.size > 1 }.blank?
  end

  def non_latin_chars?
    !all_latin_chars?
  end
end

# Restrict some queries to characters, numbers, and simple punctuation, as
# well as normalize Latin accented characters while leaving non-Latin
# characters alone.
# http://www.ruby-doc.org/core-2.0.0/Regexp.html#label-Character+Properties
# http://stackoverflow.com/a/10306827/720268
def sanitize_query( query )
  return query if query.blank?

  # rubocop:disable Layout/LineLength
  query.tr(
    "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
    "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz"
  ).gsub( /[^\p{L}\s.'\-\d]+/, "" ).gsub( /-/, "\\-" )
  # rubocop:enable Layout/LineLength
end

def private_page_cache_path( path )
  # remove absolute release path for Capistrano. Yes, this assumes you're
  # using Capistrano. Please suggest a better way.
  root = Rails.root.to_s.sub( /releases#{File::SEPARATOR}\d+/, "current" )
  File.join( root, "tmp", "page_cache", path )
end

# Haversine distance calc, adapted from http://www.movable-type.co.uk/scripts/latlong.html
def lat_lon_distance_in_meters( lat1, lon1, lat2, lon2 )
  earth_radius = 6_370_997 # m
  degrees_per_radian = 57.2958
  degrees_lat = ( lat2 - lat1 ) / degrees_per_radian
  degrees_lon = ( lon2 - lon1 ) / degrees_per_radian
  lat1 /= degrees_per_radian
  lat2 /= degrees_per_radian
  a = ( Math.sin( degrees_lat / 2 ) * Math.sin( degrees_lat / 2 ) ) +
    ( Math.sin( degrees_lon / 2 ) * Math.sin( degrees_lon / 2 ) * Math.cos( lat1 ) * Math.cos( lat2 ) )
  c = 2 * Math.atan2( Math.sqrt( a ), Math.sqrt( 1 - a ) )
  earth_radius * c
end

# rubocop:disable Lint/SuppressedException
# IDK why we're supressing this exception. If someone else wants to embrace
# the risk, go for it. ~~~kueda 20230810
def fetch_head( url, follow_redirects: true )
  begin
    uri = URI( url )
    http = Net::HTTP.new( uri.host, uri.port )
    http.use_ssl = ( url =~ /^https/ )
    rsp = http.head( uri.request_uri )
    if rsp.is_a?( Net::HTTPRedirection ) && follow_redirects
      return fetch_head( rsp["location"], false )
    end

    return rsp
  rescue StandardError
  end
  nil
end
# rubocop:enable Lint/SuppressedException

# Helper to perform a long running task, catch an exception, and try again
# after sleeping for a while
def try_and_try_again( exceptions, options = {} )
  exceptions = [exceptions].flatten
  try = 0
  tries = options.delete( :tries ) || 3
  base_sleep_duration = options.delete( :sleep ) || 60
  logger = options[:logger] || Rails.logger
  begin
    try += 1
    yield
  rescue *exceptions => e
    # raise e if ( tries -= 1 ).zero?
    raise e if try > tries

    logger.debug "Caught #{e.class}, sleeping for #{base_sleep_duration} s before trying again..."
    sleep_duration = base_sleep_duration
    if options[:exponential_backoff]
      sleep_duration = base_sleep_duration**try
    end
    sleep( sleep_duration )
    retry
  end
end
