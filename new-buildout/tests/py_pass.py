"""Module docstring."""


def add(x: int, y: int) -> int:
    """Add two numbers."""
    return x + y


class Calculator:
    """Calculator class."""

    def __init__(self, value: int = 0) -> None:
        self.value = value

    def add(self, x: int) -> int:
        """Add to value."""
        return self.value + x
