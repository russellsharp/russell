import time
from contextlib import contextmanager
from enum import Enum
from functools import wraps
from typing import Any, Callable, Generator, ParamSpec, TypeVar

type MeasureDict = dict[Enum, MeasuredTime]
type Measurements = dict[Enum, float]


class Measure:
    def __init__(self):
        self._times: MeasureDict = {}

    def start(self, category: Enum) -> None:
        self._times[category] = MeasuredTime(start=time.perf_counter())

    def stop(self, category: Enum) -> None:
        if category not in self._times:
            raise ValueError(f"Stop timing for task {category} without having started.")
        self._times[category].stop = time.perf_counter()

    def get_timings(self) -> Measurements:
        timings: Measurements = {}
        for category, timing in self._times.items():
            timings.update({category: timing.duration})
        return timings


class MeasuredTime:
    def __init__(self, start: float):
        self.start: float = start
        self.stop: float

    @property
    def duration(self) -> float:
        return self.stop - self.start

    def __repr__(self) -> str:
        return str(self.as_dict())

    def as_dict(self) -> dict[str, Any]:
        return {"start": self.start, "stop": self.stop, "duration": self.duration}


class MeasuredBase:
    def __init__(self):
        self._m = Measure()

    def get_timings(self) -> Measurements:
        return self._m.get_timings()

    @contextmanager
    def _measure(self, category: Enum) -> Generator[None, None, None]:
        try:
            self._m.start(category)
            yield
        finally:
            self._m.stop(category)


P = ParamSpec("P")
R = TypeVar("R")


def measured_function(
    measure_obj_name: str, task: Enum
) -> Callable[[Callable[P, R]], Callable[P, R]]:

    def decorator(func: Callable[P, R]) -> Callable[P, R]:

        @wraps(func)
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> Any:

            instance: Any = args[0]

            measure_obj = getattr(instance, measure_obj_name)

            measure_obj.start(task)

            result = func(*args, **kwargs)

            measure_obj.stop(task)

            return result

        return wrapper

    return decorator


def test_measure_function_decorator() -> None:

    class TestEnum(Enum):
        ONE = 1
        TWO = 2

    class TestClass:
        def __init__(self):
            self._m = Measure()

        @measured_function("_m", TestEnum.ONE)
        def decorated_func_one(self) -> None:
            # do stuff
            _ = sum(range(10000000))

        def get_timings(self) -> Measurements:
            return self._m.get_timings()

    test_instance = TestClass()

    test_instance.decorated_func_one()

    timings = test_instance.get_timings()

    assert timings

    assert len(timings.items()) > 0

    task, time = next(iter(timings.items()))

    assert task

    assert time > 0.0

    assert task == TestEnum.ONE


def test_measured_class() -> None:

    class TestEnum(Enum):
        ONE = 1
        TWO = 2

    class TestClass(MeasuredBase):
        def __init__(self):
            super().__init__()

        def func_one(self) -> None:
            # do stuff
            with self._measure(TestEnum.ONE):
                _ = sum(range(10000000))

        def get_timings(self) -> Measurements:
            return self._m.get_timings()

    test_instance = TestClass()

    test_instance.func_one()

    timings = test_instance.get_timings()

    assert timings

    assert len(timings.items()) > 0

    task, time = next(iter(timings.items()))

    assert task

    assert time > 0.0

    assert task == TestEnum.ONE
