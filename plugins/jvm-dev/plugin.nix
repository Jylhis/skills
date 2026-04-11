{ pkgs }:
{
  name = "jvm-dev";
  version = "0.1.0";
  description = "JVM development intelligence: Java 21 LTS, Kotlin 2.0+, Gradle Kotlin DSL, JUnit 5, kotest, plus jdt-language-server and kotlin-language-server LSPs and gradle-mcp";
  author.name = "Markus Jylhänkangas";

  packages = [
    pkgs.jdt-language-server
    pkgs.kotlin-language-server
    pkgs.jbang
  ];

  lspServers = {
    java = {
      command = "jdtls";
      args = [ ];
      extensionToLanguage = {
        ".java" = "java";
      };
    };
    kotlin = {
      command = "kotlin-language-server";
      args = [ ];
      extensionToLanguage = {
        ".kt" = "kotlin";
        ".kts" = "kotlin";
      };
    };
  };

  # gradle-mcp (rnett) is a JBang-based MCP server for Gradle projects.
  # Exposes project mapping, task execution, dependency search, and a
  # Kotlin REPL. First run downloads the MCP server into JBang's cache;
  # subsequent runs are local.
  mcpServers = {
    gradle = {
      type = "stdio";
      command = "jbang";
      args = [ "run" "gradle-mcp@rnett" ];
    };
  };
}
