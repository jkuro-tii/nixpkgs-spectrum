{ lib
, stdenv
, fetchFromGitHub
, fetchpatch
, cmake
, ninja
, openssl
, openjdk11
, unixODBC
, withHttpFs ? true
, withJdbc ? false
, withOdbc ? false
}:

let
  enableFeature = yes: if yes then "ON" else "OFF";
in
stdenv.mkDerivation rec {
  pname = "duckdb";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = pname;
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-dU8JXb++8OMEokr+4OyxLvcEc0vmdBvKDLxjeaWNkq0=";
  };

  postPatch = ''
    substituteInPlace CMakeLists.txt --subst-var-by DUCKDB_VERSION "v${version}"
  '';

  cmakeFlags = [
    "-DBUILD_EXCEL_EXTENSION=ON"
    "-DBUILD_FTS_EXTENSION=ON"
    "-DBUILD_HTTPFS_EXTENSION=${enableFeature withHttpFs}"
    "-DBUILD_ICU_EXTENSION=ON"
    "-DBUILD_JSON_EXTENSION=ON"
    "-DBUILD_ODBC_DRIVER=${enableFeature withOdbc}"
    "-DBUILD_PARQUET_EXTENSION=ON"
    "-DBUILD_TPCDS_EXTENSION=ON"
    "-DBUILD_TPCE=ON"
    "-DBUILD_TPCH_EXTENSION=ON"
    "-DBUILD_VISUALIZER_EXTENSION=ON"
    "-DJDBC_DRIVER=${enableFeature withJdbc}"
  ];

  doInstallCheck = true;

  preInstallCheck = ''
    export HOME="$(mktemp -d)"
  '' + lib.optionalString stdenv.isDarwin ''
    export DYLD_LIBRARY_PATH="$out/lib''${DYLD_LIBRARY_PATH:+:}''${DYLD_LIBRARY_PATH}"
  '';

  installCheckPhase =
    let
      excludes = map (pattern: "exclude:'${pattern}'") [
        "*test_slow"
        "Test file buffers for reading/writing to file"
        "[test_slow]"
        "test/common/test_cast_hugeint.test"
        "test/sql/copy/csv/test_csv_remote.test"
        "test/sql/copy/parquet/test_parquet_remote.test"
        "test/sql/copy/parquet/test_parquet_remote_foreign_files.test"
      ] ++ lib.optionals stdenv.isAarch64 [
        "test/sql/aggregate/aggregates/test_kurtosis.test"
        "test/sql/aggregate/aggregates/test_skewness.test"
        "test/sql/function/list/aggregates/skewness.test"
      ];
    in
    ''
      runHook preInstallCheck

      $PWD/test/unittest ${lib.concatStringsSep " " excludes}

      runHook postInstallCheck
    '';

  nativeBuildInputs = [ cmake ninja ];
  buildInputs = lib.optionals withHttpFs [ openssl ]
    ++ lib.optionals withJdbc [ openjdk11 ]
    ++ lib.optionals withOdbc [ unixODBC ];

  meta = with lib; {
    homepage = "https://github.com/duckdb/duckdb";
    description = "Embeddable SQL OLAP Database Management System";
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = with maintainers; [ costrouc cpcloud ];
  };
}
