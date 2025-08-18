#!@bash@

exec @plackUp@ \
  --server Starman \
	$@ \
	@psgiScript@
