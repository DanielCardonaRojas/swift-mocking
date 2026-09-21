@Test
func stubsAConcreteClass() throws {
    let loader = SpyBackedImageLoader()
    when(loader.loadSpy(.any)).thenReturn(Data([0x1]))
    when(loader.cacheSizeSpy(.any)).thenReturn(42)

    // Exercise it through the real class type — callers never know.
    let base: ImageLoader = loader
    #expect(try base.load("cat.png") == Data([0x1]))
    #expect(base.cacheSize == 42)

    verify(loader.loadSpy(.equal("cat.png"))).called(1)
}
