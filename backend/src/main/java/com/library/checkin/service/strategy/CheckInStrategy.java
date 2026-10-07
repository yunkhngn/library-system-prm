package com.library.checkin.service.strategy;

public interface CheckInStrategy<I> {
    AccessMethod method();
    IdentityProof authenticate(I input);
}
