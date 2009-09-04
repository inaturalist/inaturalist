# ***************************************************
# This tests step, next, finish and continue
# ***************************************************
set debuggertesting on
set callstyle last
continue 6
where
up
where
down
where
frame 0
where
frame -1
where
up 2
where
down 2
where
frame 0 thread 3
frame 0 thread 1
# finish
quit
