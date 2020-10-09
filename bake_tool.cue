package bake

command: {
  image: #Dubo & {
    args: {
      BUILD_TITLE: "mongoDB"
      BUILD_DESCRIPTION: "A dubo image for mongoDB based on \(args.DEBOOTSTRAP_SUITE) (\(args.DEBOOTSTRAP_DATE))"
    }
    platforms: [AMD64]
  }
}
