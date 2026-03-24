try {
  console.log(new URL(process.argv[2]).origin);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
