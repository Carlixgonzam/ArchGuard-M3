package com.example.orders;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import com.example.payments.PaymentService;
import com.example.inventory.StockManager;

@RestController
public class OrderController {

    private final PaymentService paymentService;
    private final StockManager stockManager;

    public OrderController(PaymentService paymentService, StockManager stockManager) {
        this.paymentService = paymentService;
        this.stockManager = stockManager;
    }

    @GetMapping("/orders")
    public String getAll() {
        return "orders";
    }

    @PostMapping("/orders")
    public String create() {
        stockManager.reserve();
        return paymentService.charge();
    }
}
